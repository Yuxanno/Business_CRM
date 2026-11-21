const path = require('path');
const express = require('express');
const { protect, asyncHandler } = require('../middleware/auth');
const { logError, logWarning } = require('../utils/logger');

const router = express.Router();

const GROQ_TRANSCRIPTIONS_URL =
  'https://api.groq.com/openai/v1/audio/transcriptions';

const MIME_TO_EXT = {
  'audio/mp4': 'm4a',
  'audio/m4a': 'm4a',
  'audio/x-m4a': 'm4a',
  'audio/webm': 'webm',
  'audio/ogg': 'ogg',
  'audio/wav': 'wav',
  'audio/x-wav': 'wav',
  'audio/wave': 'wav',
  'audio/mpeg': 'mp3',
  'audio/mp3': 'mp3',
  'audio/flac': 'flac',
  'audio/x-flac': 'flac',
};

const SAFE_EXTENSIONS = new Set([
  'm4a',
  'mp4',
  'webm',
  'ogg',
  'wav',
  'mp3',
  'flac',
  'oga',
  'opus',
]);

// Strictly allowed 2 languages: RUS (ru), ENG (en)
const ALLOWED_LANGS = {
  ru: 'ru',
  rus: 'ru',
  russian: 'ru',
  en: 'en',
  eng: 'en',
  english: 'en',
};

const LANG_PROMPTS = {
  ru: 'Описание работы и внутренние заметки к заказу на русском языке.',
  en: 'Work description and internal order notes in English.',
};

const SLAVIC_LANGS = new Set([
  'russian',
  'ru',
  'ukrainian',
  'uk',
  'belarusian',
  'be',
  'bulgarian',
  'bg',
  'serbian',
  'sr',
  'macedonian',
  'mk',
]);

function normalizeAllowedLanguage(rawLang) {
  const key = String(rawLang || '')
    .trim()
    .toLowerCase();
  return ALLOWED_LANGS[key] || null;
}

function mapDetectedToAllowed(detectedLang) {
  const key = String(detectedLang || '')
    .trim()
    .toLowerCase();
  if (ALLOWED_LANGS[key]) return ALLOWED_LANGS[key];
  if (SLAVIC_LANGS.has(key)) return 'ru';
  return 'ru';
}

const PHANTOM_PHRASES = new Set([
  'thank you',
  'thanks for watching',
  'thank you for watching',
  'subtitles by',
  'спасибо за просмотр',
  'продолжение следует',
  'подписывайтесь на канал',
  'субтитры делал',
  'субтитры создавал',
  'you',
  '.',
  '...',
]);

function extensionFromMime(contentType, filenameHeader) {
  const mime = String(contentType || '')
    .split(';')[0]
    .trim()
    .toLowerCase();

  if (MIME_TO_EXT[mime]) {
    return MIME_TO_EXT[mime];
  }

  if (filenameHeader) {
    const ext = path
      .extname(String(filenameHeader).trim())
      .replace(/^\./, '')
      .toLowerCase();
    if (SAFE_EXTENSIONS.has(ext)) {
      return ext;
    }
  }

  return 'm4a';
}

function isLikelyHallucination(text, segments) {
  const trimmed = String(text || '').trim();
  if (!trimmed) return true;

  if (Array.isArray(segments) && segments.length > 0) {
    const allSilent = segments.every(
      (seg) => (Number(seg?.no_speech_prob) || 0) > 0.85
    );
    if (allSilent) return true;

    const avgNoSpeech =
      segments.reduce(
        (sum, seg) => sum + (Number(seg?.no_speech_prob) || 0),
        0
      ) / segments.length;

    const lower = trimmed.toLowerCase();
    const normalized = lower
      .replace(/[.!?,…:;"'()\[\]]+/g, '')
      .replace(/\s+/g, ' ')
      .trim();

    if (
      avgNoSpeech > 0.55 &&
      (PHANTOM_PHRASES.has(lower) ||
        PHANTOM_PHRASES.has(normalized) ||
        !normalized)
    ) {
      return true;
    }
  }

  return false;
}

async function callGroqTranscription({
  apiKey,
  buffer,
  mimeType,
  filename,
  model,
  language,
}) {
  const form = new FormData();
  form.append('file', new Blob([buffer], { type: mimeType }), filename);
  form.append('model', model);
  form.append('response_format', 'verbose_json');
  form.append('temperature', '0');

  if (language && ALLOWED_LANGS[language]) {
    const code = ALLOWED_LANGS[language];
    form.append('language', code);
    form.append('prompt', LANG_PROMPTS[code]);
  }

  const resp = await fetch(GROQ_TRANSCRIPTIONS_URL, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${apiKey}`,
    },
    body: form,
    signal: AbortSignal.timeout(25000),
  });

  const rawBody = await resp.text();
  let data = null;
  if (rawBody) {
    try {
      data = JSON.parse(rawBody);
    } catch (_) {
      data = { raw: rawBody };
    }
  }

  return { status: resp.status, ok: resp.ok, data };
}

// ─── @route   POST /api/speech/transcribe ────────────────────────────────────
// ─── @desc    Transcribe an audio note via Groq Whisper (UZB / RUS / ENG) ────
router.post(
  '/transcribe',
  protect,
  express.raw({
    type: ['audio/*', 'application/octet-stream'],
    limit: '15mb',
  }),
  asyncHandler(async (req, res) => {
    const apiKey = (process.env.GROQ_API_KEY || '').trim();
    if (!apiKey) {
      res.status(503);
      throw new Error(
        'Голосовой ввод не настроен (добавьте GROQ_API_KEY в .env)'
      );
    }

    if (!Buffer.isBuffer(req.body) || req.body.length < 1000) {
      res.status(400);
      throw new Error('Запись слишком короткая — попробуйте ещё раз');
    }

    const rawContentType = String(req.headers['content-type'] || 'audio/mp4')
      .split(';')[0]
      .trim()
      .toLowerCase();
    const ext = extensionFromMime(
      rawContentType,
      req.headers['x-audio-filename']
    );
    const filename = `note.${ext}`;
    const mimeType = rawContentType.startsWith('audio/')
      ? rawContentType
      : 'audio/mp4';

    // Explicit language requested by client (uz | ru | en)
    const requestedLang = normalizeAllowedLanguage(
      req.headers['x-audio-language'] || req.query.lang
    );

    const primaryModel = (
      process.env.GROQ_STT_MODEL || 'whisper-large-v3'
    ).trim();
    const fallbackModel =
      primaryModel === 'whisper-large-v3'
        ? 'whisper-large-v3-turbo'
        : 'whisper-large-v3';

    let usedModel = primaryModel;
    let result;
    try {
      result = await callGroqTranscription({
        apiKey,
        buffer: req.body,
        mimeType,
        filename,
        model: primaryModel,
        language: requestedLang,
      });

      if (result.status === 429) {
        logWarning(
          `Groq STT 429 на модели ${primaryModel}, переключаемся на ${fallbackModel}`
        );
        usedModel = fallbackModel;
        result = await callGroqTranscription({
          apiKey,
          buffer: req.body,
          mimeType,
          filename,
          model: fallbackModel,
          language: requestedLang,
        });
      }

      // If no explicit language was locked and Whisper detected a language
      // outside {uz, ru, en} (e.g. Turkish instead of Uzbek), re-transcribe
      // locked to the mapped allowed language (uz | ru | en).
      if (result.ok && !requestedLang) {
        const detected = String(result.data?.language || '')
          .trim()
          .toLowerCase();
        if (!ALLOWED_LANGS[detected]) {
          const mappedLang = mapDetectedToAllowed(detected);
          const retried = await callGroqTranscription({
            apiKey,
            buffer: req.body,
            mimeType,
            filename,
            model: usedModel,
            language: mappedLang,
          });
          if (retried.ok) {
            result = retried;
          }
        }
      }
    } catch (err) {
      logError(req.method, req.originalUrl, err, { model: usedModel });
      res.status(err.name === 'TimeoutError' ? 504 : 502);
      throw new Error('Не удалось связаться с сервисом распознавания речи');
    }

    if (!result.ok) {
      if (result.status === 401) {
        res.status(502);
        throw new Error('Неверный ключ GROQ_API_KEY');
      }
      if (result.status === 429) {
        res.status(429);
        throw new Error(
          'Лимит запросов Groq временно исчерпан, попробуйте через минуту'
        );
      }

      logError(
        req.method,
        req.originalUrl,
        new Error(`Groq HTTP ${result.status}`),
        { model: usedModel, response: result.data }
      );
      res.status(502);
      throw new Error('Ошибка распознавания речи');
    }

    const rawText = String(result.data?.text || '').trim();
    const finalLang =
      requestedLang || mapDetectedToAllowed(result.data?.language);
    const segments = result.data?.segments;

    if (isLikelyHallucination(rawText, segments)) {
      return res.json({
        text: '',
        language: finalLang,
        noSpeech: true,
        model: usedModel,
      });
    }

    return res.json({
      text: rawText,
      language: finalLang,
      noSpeech: false,
      model: usedModel,
    });
  })
);

router._test = {
  extensionFromMime,
  isLikelyHallucination,
  normalizeAllowedLanguage,
  mapDetectedToAllowed,
};

module.exports = router;

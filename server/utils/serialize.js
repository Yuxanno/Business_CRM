/** Convert a mongoose doc / lean object to Flutter-friendly JSON. */
function serialize(doc) {
  if (!doc) return null;
  const obj = typeof doc.toObject === 'function' ? doc.toObject() : { ...doc };
  const id = obj.id || (obj._id != null ? String(obj._id) : undefined);
  delete obj._id;
  delete obj.__v;
  return { ...obj, id };
}

function serializeMany(docs) {
  return (docs || []).map(serialize);
}

module.exports = { serialize, serializeMany };

module.exports = {
  transform: function (obj) {
    if (obj.type !== "Literal") {
      throw Error('Unexpected object type; Expecting "Literal"');
    }

    if (obj.value === null) {
      obj.value = "'null";
      obj.raw = "\"'null\""
    }

    return obj
  }
}

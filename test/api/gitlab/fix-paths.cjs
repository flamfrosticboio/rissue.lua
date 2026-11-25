function fixGrapePaths() {
  return {
    Root: {
      leave(root) {
        const fixed = {};
        for (const [path, item] of Object.entries(root.paths || {})) {
          const clean = path.replace(/\(-\/\)/g, "");
          // merge in case the clean path already exists
          fixed[clean] = fixed[clean] ? { ...fixed[clean], ...item } : item;
        }
        root.paths = fixed;
      },
    },
  };
}

module.exports = function gitlabPlugin() {
  return {
    id: "gitlab",
    decorators: {
      oas2: { "fix-grape-paths": fixGrapePaths },
      oas3: { "fix-grape-paths": fixGrapePaths },
    },
  };
};

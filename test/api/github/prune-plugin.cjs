const unesc = (s) =>
  decodeURIComponent(s).replace(/~1/g, "/").replace(/~0/g, "~");

module.exports = {
  id: "prune",
  decorators: {
    oas3: {
      "prune-components": () => ({
        Root: {
          leave(root) {
            const { components, ...rest } = root;
            if (!components) return;
            const used = new Set();
            const walk = (n) => {
              if (Array.isArray(n)) return n.forEach(walk);
              if (!n || typeof n !== "object") return;
              for (const [k, v] of Object.entries(n)) {
                if (
                  k === "$ref" &&
                  typeof v === "string" &&
                  v.startsWith("#/components/")
                ) {
                  const [type, name] = v.slice(13).split("/").map(unesc);
                  const key = `${type}/${name}`;
                  if (!used.has(key)) {
                    used.add(key);
                    walk(components[type]?.[name]);
                  }
                } else walk(v);
              }
            };
            walk(rest);
            for (const [type, group] of Object.entries(components)) {
              if (type === "securitySchemes") continue;
              for (const name of Object.keys(group))
                if (!used.has(`${type}/${name}`)) delete group[name];
              if (!Object.keys(group).length) delete components[type];
            }
          },
        },
      }),
    },
  },
};

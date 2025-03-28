// See the Tailwind configuration guide for advanced usage
// https://tailwindcss.com/docs/configuration

const plugin = require("tailwindcss/plugin");
const fs = require("fs");
const path = require("path");

module.exports = {
  content: ["./js/**/*.js", "../lib/gang_web.ex", "../lib/gang_web/**/*.*ex"],
  theme: {
    extend: {
      colors: {
        brand: "#FD4F00",
        // Catppuccin Mocha Colors
        "ctp-rosewater": "#f5e0dc",
        "ctp-flamingo": "#f2cdcd",
        "ctp-pink": "#f5c2e7",
        "ctp-mauve": "#cba6f7",
        "ctp-red": "#f38ba8",
        "ctp-maroon": "#eba0ac",
        "ctp-peach": "#fab387",
        "ctp-yellow": "#f9e2af",
        "ctp-green": "#a6e3a1",
        "ctp-teal": "#94e2d5",
        "ctp-sky": "#89dceb",
        "ctp-sapphire": "#74c7ec",
        "ctp-blue": "#89b4fa",
        "ctp-lavender": "#b4befe",
        "ctp-text": "#cdd6f4",
        "ctp-subtext1": "#bac2de",
        "ctp-subtext0": "#a6adc8",
        "ctp-overlay2": "#9399b2",
        "ctp-overlay1": "#7f849c",
        "ctp-overlay0": "#6c7086",
        "ctp-surface2": "#585b70",
        "ctp-surface1": "#45475a",
        "ctp-surface0": "#313244",
        "ctp-base": "#1e1e2e",
        "ctp-mantle": "#181825",
        "ctp-crust": "#11111b",
      },
      keyframes: {
        "fade-in-out-1": {
          "0%, 100%": { opacity: "0" },
          "30%, 70%": { opacity: "0.15" },
          "50%": { opacity: "0.2" },
        },
        "fade-in-out-2": {
          "0%, 100%": { opacity: "0" },
          "20%, 60%": { opacity: "0.12" },
          "40%": { opacity: "0.18" },
        },
        "fade-in-out-3": {
          "0%, 100%": { opacity: "0" },
          "40%, 80%": { opacity: "0.1" },
          "60%": { opacity: "0.15" },
        },
        "fade-float-1": {
          "0%, 100%": {
            opacity: "0",
            transform: "translateY(0) translateX(0)",
          },
          "30%, 70%": {
            opacity: "0.12",
            transform: "translateY(-20px) translateX(20px)",
          },
          "50%": {
            opacity: "0.18",
            transform: "translateY(-30px) translateX(30px)",
          },
        },
        "fade-float-2": {
          "0%, 100%": {
            opacity: "0",
            transform: "translateY(0) translateX(0)",
          },
          "30%, 70%": {
            opacity: "0.15",
            transform: "translateY(20px) translateX(-20px)",
          },
          "50%": {
            opacity: "0.2",
            transform: "translateY(30px) translateX(-30px)",
          },
        },
      },
      animation: {
        "fade-in-out-1": "fade-in-out-1 12s ease-in-out infinite",
        "fade-in-out-2": "fade-in-out-2 15s ease-in-out infinite",
        "fade-in-out-3": "fade-in-out-3 18s ease-in-out infinite",
        "fade-float-1": "fade-float-1 20s ease-in-out infinite",
        "fade-float-2": "fade-float-2 16s ease-in-out infinite",
      },
    },
  },
  plugins: [
    require("@tailwindcss/forms"),
    // Allows prefixing tailwind classes with LiveView classes to add rules
    // only when LiveView classes are applied, for example:
    //
    //     <div class="phx-click-loading:animate-ping">
    //
    plugin(({ addVariant }) =>
      addVariant("phx-click-loading", [
        ".phx-click-loading&",
        ".phx-click-loading &",
      ])
    ),
    plugin(({ addVariant }) =>
      addVariant("phx-submit-loading", [
        ".phx-submit-loading&",
        ".phx-submit-loading &",
      ])
    ),
    plugin(({ addVariant }) =>
      addVariant("phx-change-loading", [
        ".phx-change-loading&",
        ".phx-change-loading &",
      ])
    ),

    // Embeds Heroicons (https://heroicons.com) into your app.css bundle
    // See your `CoreComponents.icon/1` for more information.
    //
    plugin(function ({ matchComponents, theme }) {
      let iconsDir = path.join(__dirname, "../deps/heroicons/optimized");
      let values = {};
      let icons = [
        ["", "/24/outline"],
        ["-solid", "/24/solid"],
        ["-mini", "/20/solid"],
        ["-micro", "/16/solid"],
      ];
      icons.forEach(([suffix, dir]) => {
        fs.readdirSync(path.join(iconsDir, dir)).forEach((file) => {
          let name = path.basename(file, ".svg") + suffix;
          values[name] = { name, fullPath: path.join(iconsDir, dir, file) };
        });
      });
      matchComponents(
        {
          hero: ({ name, fullPath }) => {
            let content = fs
              .readFileSync(fullPath)
              .toString()
              .replace(/\r?\n|\r/g, "");
            let size = theme("spacing.6");
            if (name.endsWith("-mini")) {
              size = theme("spacing.5");
            } else if (name.endsWith("-micro")) {
              size = theme("spacing.4");
            }
            return {
              [`--hero-${name}`]: `url('data:image/svg+xml;utf8,${content}')`,
              "-webkit-mask": `var(--hero-${name})`,
              mask: `var(--hero-${name})`,
              "mask-repeat": "no-repeat",
              "background-color": "currentColor",
              "vertical-align": "middle",
              display: "inline-block",
              width: size,
              height: size,
            };
          },
        },
        { values }
      );
    }),
  ],
};

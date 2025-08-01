// If you want to use Phoenix channels, run `mix help phx.gen.channel`
// to get started and then uncomment the line below.
// import "./user_socket.js"

// You can include dependencies in two ways.
//
// The simplest option is to put them in assets/vendor and
// import them using relative paths:
//
//     import "../vendor/some-package.js"
//
// Alternatively, you can `npm install some-package --prefix assets` and import
// them using a path starting with the package name:
//
//     import "some-package"
//

// Include phoenix_html to handle method=PUT/DELETE in forms and buttons.
import "phoenix_html";
// Establish Phoenix Socket and LiveView configuration.
import { Socket } from "phoenix";
import { LiveSocket } from "phoenix_live_view";
import topbar from "../vendor/topbar";
import { hooks as colocatedHooks } from "phoenix-colocated/gang";

const Hooks = {
  SetPlayerName: {
    mounted() {
      // Check if we already have a player name and ID in localStorage
      const savedName = localStorage.getItem("player_name");
      const savedId = localStorage.getItem("player_id");
      if (savedName && savedId) {
        const input = this.el.querySelector('input[name="player_name"]');
        if (input) {
          input.value = savedName;
        }
        // Push the saved name and ID to the server
        this.pushEvent("restore_player_info", {
          player_name: savedName,
          player_id: savedId,
        });
      }

      this.handleEvent("save_player_info", ({ player_name, player_id }) => {
        localStorage.setItem("player_name", player_name);
        localStorage.setItem("player_id", player_id);
      });
    },
  },
  Clipboard: {
    mounted() {
      this.el.addEventListener("click", (e) => {
        const textToCopy = this.el.dataset.clipboardText;
        navigator.clipboard
          .writeText(textToCopy)
          .then(() => {
            console.log("Copied to clipboard: ", textToCopy);
            // Optional: Add feedback to the user, like changing the icon or showing a tooltip
          })
          .catch((err) => {
            console.error("Failed to copy: ", err);
          });
      });

      // Listen for the server event
      this.handleEvent("copy_to_clipboard", ({ text }) => {
        navigator.clipboard
          .writeText(text)
          .then(() => {
            console.log("Copied share link to clipboard: ", text);
            // Optional: Provide user feedback (e.g., show a temporary message)
            this.el.focus(); // Briefly focus the button for visual feedback
            // You might want to add a small temporary text indicator like "Copied!" next to the button
          })
          .catch((err) => {
            console.error("Failed to copy share link: ", err);
          });
      });
    },
  },
};

let csrfToken = document
  .querySelector("meta[name='csrf-token']")
  .getAttribute("content");

let liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbackMs: 2500,
  params: () => {
    // Send current localStorage data on every connection/reconnection
    return {
      _csrf_token: csrfToken,
      player_name: localStorage.getItem("player_name") || "",
      player_id: localStorage.getItem("player_id") || "",
    };
  },
  hooks: { ...Hooks, ...colocatedHooks },
});

// Chat functionality
window.addEventListener("phx:scroll_chat_to_bottom", () => {
  // Use requestAnimationFrame for better timing with browser rendering
  requestAnimationFrame(() => {
    // Add additional delay to ensure DOM is fully updated
    setTimeout(() => {
      const scrollToBottom = (element) => {
        if (element) {
          // Try multiple approaches for reliability
          element.scrollTop = element.scrollHeight;

          const lastMessage = element.lastElementChild;
          if (lastMessage) {
            lastMessage.scrollIntoView({ behavior: "instant", block: "end" });
          }

          setTimeout(() => {
            element.scrollTop = element.scrollHeight;
          }, 10);
        }
      };

      // Scroll all chat message containers using shared CSS class
      const containers = document.querySelectorAll(".chat-messages");

      containers.forEach((container) => {
        scrollToBottom(container);
      });
    }, 100);
  });
});

// Show progress bar on live navigation and form submits
topbar.config({ barColors: { 0: "#29d" }, shadowColor: "rgba(0, 0, 0, .3)" });
window.addEventListener("phx:page-loading-start", (_info) => topbar.show(300));
window.addEventListener("phx:page-loading-stop", (_info) => topbar.hide());

// connect if there are any LiveViews on the page
liveSocket.connect();

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket;

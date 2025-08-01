defmodule GangWeb.ChatComponents do
  @moduledoc false
  use Phoenix.Component

  import GangWeb.CoreComponents, only: [icon: 1]

  alias Phoenix.LiveView.JS

  @doc """
  Chat panel component with glass styling for the Gang poker game.

  Displays a traditional chat interface with:
  - Desktop: Fixed positioned panel in bottom-right
  - Mobile: Full-width component that integrates with game layout
  - Glass/transparent styling to not distract from gameplay
  - Mock data for rapid design iteration
  """
  def chat_panel(assigns) do
    # Use real messages or fallback to empty list
    messages = Map.get(assigns, :messages, [])

    # Format timestamps for display
    formatted_messages =
      Enum.map(messages, fn msg ->
        %{
          id: msg.id,
          player_name: msg.player_name,
          player_avatar: msg.player_avatar,
          message: msg.message,
          timestamp: format_message_time(msg.timestamp)
        }
      end)

    assigns = assign(assigns, :messages, formatted_messages)

    ~H"""
    <!-- Desktop Chat Panel -->
    <div class="hidden md:block fixed bottom-4 right-4 z-10 chat-container">
      <!-- Collapsed Chat Badge -->
      <button
        phx-click={show_chat()}
        class="chat-collapsed relative bg-ctp-base/10 backdrop-blur-xl rounded-full border border-ctp-surface0/10 shadow-lg shadow-ctp-crust/10 p-4 hover:bg-ctp-base/20 transition-all"
      >
        <.icon name="hero-chat-bubble-left-right" class="h-6 w-6 text-ctp-lavender" />
        <%= if length(@messages) > 0 do %>
          <span class="absolute -top-1 -right-1 bg-ctp-red text-ctp-base text-xs rounded-full min-w-[1.25rem] h-5 flex items-center justify-center px-1 font-medium">
            {length(@messages)}
          </span>
        <% end %>
      </button>
      
    <!-- Expanded Chat Panel -->
      <div class="chat-expanded hidden w-80 h-96">
        <div class="bg-ctp-base/5 backdrop-blur-xl rounded-lg border border-ctp-surface0/10 shadow-lg shadow-ctp-crust/10 flex flex-col h-full">
          <!-- Chat Header -->
          <div class="flex items-center justify-between p-3 border-b border-ctp-surface0/10">
            <h3 class="text-sm font-medium text-ctp-text">Game Chat</h3>
            <div class="flex items-center space-x-2">
              <span class="text-xs text-ctp-subtext0">#{length(@messages)} messages</span>
              <button
                phx-click={hide_chat()}
                class="text-ctp-subtext0 hover:text-ctp-text transition-colors p-1"
              >
                <span class="text-sm">−</span>
              </button>
            </div>
          </div>
          
    <!-- Messages Area -->
          <div class="flex-1 overflow-y-auto p-3 space-y-2 chat-messages">
            <%= for message <- @messages do %>
              <div class="flex flex-col space-y-1">
                <div class="flex items-center space-x-2">
                  <!-- Player Avatar -->
                  <img
                    src={message.player_avatar}
                    alt={message.player_name <> " avatar"}
                    class="w-6 h-6 rounded-full flex-shrink-0 object-cover"
                  />
                  <span class="text-sm font-medium text-ctp-text truncate">
                    {message.player_name}
                  </span>
                  <span class="text-xs text-ctp-subtext0 ml-auto">{message.timestamp}</span>
                </div>
                <div class="bg-ctp-surface0/20 backdrop-blur-sm rounded-lg px-3 py-2 ml-8">
                  <p class="text-sm text-ctp-text break-words">{message.message}</p>
                </div>
              </div>
            <% end %>
          </div>
          
    <!-- Chat Input -->
          <div class="p-3 border-t border-ctp-surface0/10">
            <.form for={@chat_form} phx-submit="send_chat_message" phx-change="chat_form_change" class="flex space-x-2">
              <input
                name="message"
                type="text"
                value={@chat_form.data["message"]}
                placeholder="Type a message..."
                maxlength="140"
                class="flex-1 bg-ctp-surface0/20 backdrop-blur-sm border border-ctp-surface1/10 rounded-lg px-3 py-2 text-sm text-ctp-text placeholder-ctp-subtext0 focus:outline-none focus:ring-2 focus:ring-ctp-lavender/50 focus:border-ctp-lavender/50"
                required
              />
              <button
                type="submit"
                class="bg-ctp-lavender/80 hover:bg-ctp-lavender text-ctp-base rounded-lg px-4 py-2 text-sm font-medium transition-colors backdrop-blur-sm"
              >
                Send
              </button>
            </.form>
          </div>
        </div>
      </div>
    </div>

    <!-- Mobile Chat Panel -->
    <div class="md:hidden chat-container">
      <!-- Collapsed Chat Badge for Mobile -->
      <button
        phx-click={show_chat()}
        class="chat-collapsed w-full bg-ctp-base/10 backdrop-blur-xl rounded-lg border border-ctp-surface0/10 shadow-lg shadow-ctp-crust/10 p-3 hover:bg-ctp-base/20 transition-all"
      >
        <div class="flex items-center justify-between">
          <div class="flex items-center space-x-2">
            <.icon name="hero-chat-bubble-left-right" class="h-5 w-5 text-ctp-lavender" />
            <span class="text-sm font-medium text-ctp-text">Game Chat</span>
          </div>
          <%= if length(@messages) > 0 do %>
            <span class="bg-ctp-red text-ctp-base text-xs rounded-full min-w-[1.25rem] h-5 flex items-center justify-center px-2 font-medium">
              {length(@messages)}
            </span>
          <% end %>
        </div>
      </button>
      
    <!-- Expanded Chat Panel for Mobile -->
      <div class="chat-expanded hidden bg-ctp-base/5 backdrop-blur-xl rounded-lg border border-ctp-surface0/10 shadow-lg shadow-ctp-crust/10">
        <!-- Chat Header -->
        <div class="flex items-center justify-between p-3 border-b border-ctp-surface0/10">
          <h3 class="text-sm font-medium text-ctp-text">Game Chat</h3>
          <div class="flex items-center space-x-2">
            <span class="text-xs text-ctp-subtext0">#{length(@messages)} messages</span>
            <button
              phx-click={hide_chat()}
              class="text-ctp-subtext0 hover:text-ctp-text transition-colors p-1"
            >
              <span class="text-sm">−</span>
            </button>
          </div>
        </div>
        
    <!-- Messages Area - Compact for Mobile -->
        <div class="max-h-48 overflow-y-auto p-3 space-y-2 chat-messages">
          <%= for message <- Enum.take(@messages, -3) do %>
            <div class="flex flex-col space-y-1">
              <div class="flex items-center space-x-2">
                <img
                  src={message.player_avatar}
                  alt={message.player_name <> " avatar"}
                  class="w-5 h-5 rounded-full flex-shrink-0 object-cover"
                />
                <span class="text-sm font-medium text-ctp-text truncate">
                  {message.player_name}
                </span>
                <span class="text-xs text-ctp-subtext0 ml-auto">{message.timestamp}</span>
              </div>
              <div class="bg-ctp-surface0/20 backdrop-blur-sm rounded-lg px-3 py-2 ml-6">
                <p class="text-sm text-ctp-text break-words">{message.message}</p>
              </div>
            </div>
          <% end %>
        </div>
        
    <!-- Chat Input -->
        <div class="p-3 border-t border-ctp-surface0/10">
          <.form for={@chat_form} phx-submit="send_chat_message" phx-change="chat_form_change" class="flex space-x-2">
              <input
                name="message"
                type="text"
                value={@chat_form.data["message"]}
                placeholder="Type a message..."
                maxlength="140"
                class="flex-1 bg-ctp-surface0/20 backdrop-blur-sm border border-ctp-surface1/10 rounded-lg px-3 py-2 text-sm text-ctp-text placeholder-ctp-subtext0 focus:outline-none focus:ring-2 focus:ring-ctp-lavender/50 focus:border-ctp-lavender/50"
                required
              />
            <button
              type="submit"
              class="bg-ctp-lavender/80 hover:bg-ctp-lavender text-ctp-base rounded-lg px-3 py-2 text-sm font-medium transition-colors backdrop-blur-sm"
            >
              Send
            </button>
          </.form>
        </div>
      </div>
    </div>
    """
  end

  # LiveView.JS helper functions for chat show/hide
  defp show_chat() do
    JS.hide(to: ".chat-collapsed")
    |> JS.show(to: ".chat-expanded")
  end

  defp hide_chat() do
    JS.hide(to: ".chat-expanded")
    |> JS.show(to: ".chat-collapsed")
  end

  # Helper function to format message timestamps
  # Simple approach: use Calendar.strftime with basic format
  # This will use the server's local time, which is better than UTC for most users
  defp format_message_time(timestamp) when is_struct(timestamp, DateTime) do
    Calendar.strftime(timestamp, "%I:%M %p")
  rescue
    _ ->
      # Ultimate fallback - just show time portion
      timestamp
      |> DateTime.to_time()
      |> Time.to_string()
      |> String.slice(0, 5)
  end

  defp format_message_time(_), do: ""
end

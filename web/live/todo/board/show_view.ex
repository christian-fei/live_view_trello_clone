defmodule Apps.TrelloClone.Web.Live.Todo.Board.ShowView do
  @moduledoc """
  Show a single board
  """
  use Phoenix.LiveView

  alias Apps.TrelloClone.Contexts.Todo
  alias Apps.TrelloClone.Web.Live.Todo.Components

  @impl true
  def render(assigns) do
    ~L"""
    <%= @board.title %>
    <div class="board">
      <div class="lists">
        <div id="lists">
          <%= for list <- @lists do %>
            <%= live_component @socket, Components.List, id: list.id %>
          <% end %>
        </div>
        <div class="list_actions">
          <%= live_component @socket, Components.ListCreator, id: :list_creator, board: @board %>
          <br style="clear: left;" />
        </div>
      </div>
      <style>
        .lists {
          width: <%= @columns * 300 %>px;
        }
      </style>
    </div>

    <%= if @selected_item do %>
      <%= live_component @socket, Components.ItemModal, id: :item_modal, item: @selected_item %>
    <% end %>
    """
  end

  @impl true
  def mount(%{"id" => id} = _params, _session, socket) do
    if connected?(socket), do: Todo.subscribe()
    board = Todo.get_board!(id)

    {:ok,
     assign(socket,
       board: board,
       lists: board.lists,
       columns: column_size(board),
       selected_item: Todo.get_item!("80b68dcf-314e-4175-a6ae-ede9d3760840")
     )}
  end

  @impl true
  def handle_info(:load_board, socket) do
    board = Todo.get_board!(socket.assigns.board.id)

    {:noreply,
     assign(socket,
       board: board,
       lists: board.lists,
       columns: column_size(board)
     )}
  end

  @impl true
  def handle_event("toggle_list", %{"list_id" => id} = _event, socket) do
    {:ok, _list} = Todo.toggle_list(id)
    {:noreply, socket}
  end

  @impl true
  def handle_event("delete_list", %{"list_id" => id} = _event, socket) do
    {:ok, _schema} = Todo.delete_list(id)
    {:noreply, socket}
  end

  @impl true
  def handle_event("move_item", %{"id" => item_id, "to_list_id" => list_id} = _event, socket) do
    list = Todo.get_list!(list_id)
    {:ok, _item} = Todo.move_item_to(item_id, list.id)
    send(self(), :load_board)
    {:noreply, socket}
  end

  @impl true
  def handle_event(
        "swap_lists",
        %{"id" => from_id, "to_list_id" => to_id} = _event,
        socket
      ) do
    source_list = Todo.get_list!(from_id)
    target_list = Todo.get_list!(to_id)
    {:ok, _list} = Todo.swap_lists(source_list, target_list)
    send(self(), :load_board)
    {:noreply, socket}
  end

  @impl true
  def handle_event("item_clicked", %{"draggable_id" => ""} = _event, socket) do
    {:noreply, assign(socket, selected_item: nil)}
  end

  @impl true
  def handle_event("item_clicked", %{"draggable_id" => id} = _event, socket) do
    {:noreply, assign(socket, selected_item: Todo.get_item!(id))}
  end

  defp column_size(board) do
    length(board.lists) + 1
  end

  ###################### PubSub Events ######################

  @impl true
  def handle_info({:item_created, item}, socket) do
    # Send update to the appropriate list
    send_update(Components.List, id: item.list_id)
    {:noreply, socket}
  end

  @impl true
  def handle_info({:item_updated, item}, socket) do
    # Send update to the appropriate list
    send_update(Components.Item, id: item.id, item: item)
    send_update(Components.ItemModal, id: :item_modal, item: item)
    {:noreply, socket}
  end

  @impl true
  def handle_info({:item_deleted, item}, socket) do
    # Send update to the appropriate list
    send_update(Components.List, id: item.list_id)
    {:noreply, assign(socket, selected_item: nil)}
  end

  @impl true
  def handle_info({:item_moved, item, previous_list_id}, socket) do
    # Send update to the appropriate lists
    send_update(Components.List, id: item.list_id)
    send_update(Components.List, id: previous_list_id)
    {:noreply, socket}
  end

  @impl true
  def handle_info({:item_label_changed, item}, socket) do
    # Send update to the appropriate item (and modal)
    send_update(Components.Item, id: item.id, item: item)
    send_update(Components.ItemModal, id: :item_modal, item: item)
    {:noreply, socket}
  end

  @impl true
  def handle_info({:list_created, _list}, socket) do
    # TODO: Maybe patch lists, instead of reloading everything
    send(self(), :load_board)
    {:noreply, socket}
  end

  @impl true
  def handle_info({:list_updated, list}, socket) do
    # Send update to the appropriate list
    send_update(Components.List, id: list.id, list: list)
    {:noreply, socket}
  end

  @impl true
  def handle_info({:list_deleted, _list}, socket) do
    # TODO: Maybe patch lists, instead of reloading everything
    send(self(), :load_board)
    {:noreply, socket}
  end

  @impl true
  def handle_info({:list_toggled, _list}, socket) do
    # TODO: Maybe patch lists, instead of reloading everything
    send(self(), :load_board)
    {:noreply, socket}
  end

  @impl true
  def handle_info({:lists_swapped, _list, _other_list}, socket) do
    # TODO: Maybe patch lists, instead of reloading everything
    send(self(), :load_board)
    {:noreply, socket}
  end
end

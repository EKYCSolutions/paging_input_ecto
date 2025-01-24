defmodule PagingInputEcto do
  @moduledoc false

  defstruct page_size: 8, page_number: nil, cursor_id: nil, sort_direction: :desc

  @type t :: %__MODULE__{
    page_size: integer(),
    page_number: integer(),
    cursor_id: String.t(),
    sort_direction: :asc | :desc
  }

  import Ecto.Query, only: [limit: 2, where: 3, offset: 2, order_by: 3]

  def new() do
    %__MODULE__{}
  end

  def put_page_number(%__MODULE__{} = paging_input, %{"page_number" => page_number}) when page_number >= 0,
    do: %{paging_input | page_number: page_number}

  def put_page_number(paging_input, _args),
    do: paging_input

  def put_page_size(%__MODULE__{} = paging_input, %{"page_size" => page_size}) when page_size > 32,
    do: %{paging_input | page_size: 32}

  def put_page_size(%__MODULE__{} = paging_input, %{"page_size" => page_size}) when page_size > 0,
    do: %{paging_input | page_size: page_size}

  def put_page_size(%__MODULE__{} = paging_input, _args),
    do: paging_input

  def put_sort_direction(%__MODULE__{} = paging_input, %{"sort_direction" => "asc"}),
    do: %{paging_input | sort_direction: :asc}

  def put_sort_direction(%__MODULE__{} = paging_input, _args),
    do: %{paging_input | sort_direction: :desc}

  def put_cursor_id(%__MODULE__{} = paging_input, %{"cursor_id" => "uuidv7:" <> cursor_id}) do
    case UUIDv7.dump(cursor_id) do
      {:ok, _} -> %{paging_input | cursor_id: cursor_id}

      _ -> paging_input
    end
  end

  def put_cursor_id(%__MODULE__{} = paging_input, %{"cursor_id" => "integer:" <> cursor_id}) do
    case Integer.parse(cursor_id) do
      {cursor_id, _} ->
        %{paging_input | cursor_id: cursor_id}

      _ -> paging_input
    end
  end

  def put_cursor_id(%__MODULE__{} = paging_input, _args),
    do: paging_input

  defp apply_cursor_query(query, %__MODULE__{cursor_id: cursor_id, sort_direction: :asc}) when not is_nil(cursor_id),
    do: where(query, [e], e.id > ^cursor_id)

  defp apply_cursor_query(query, %__MODULE__{cursor_id: cursor_id, sort_direction: :desc}) when not is_nil(cursor_id),
    do: where(query, [e], e.id < ^cursor_id)

  defp apply_cursor_query(query, _paging_input),
    do: query

  defp apply_limit_offset_query(query, %__MODULE__{page_number: pn, cursor_id: nil} = paging_input) when not is_nil(pn),
    do: offset(query, ^(paging_input.page_number * paging_input.page_size))

  defp apply_limit_offset_query(query, _paging_input),
    do: query

  def apply_to_ecto_query(query, %__MODULE__{} = paging_input) do
    query
    |> apply_cursor_query(paging_input)
    |> apply_limit_offset_query(paging_input)
    |> limit(^paging_input.page_size)
    |> order_by([e], {^paging_input.sort_direction, :id})
  end

  def from_conn(%Plug.Conn{query_params: query_params} = conn) do
    conn = %{
      conn
      | query_params:
          Enum.reduce(query_params, %{}, fn
            {"page_number", page_number}, query_params ->
              case Integer.parse(page_number) do
                {page_number, _} ->
                  Map.put(query_params, "page_number", page_number)

                :error ->
                  query_params
              end

            {"page_size", page_size}, query_params ->
              case Integer.parse(page_size) do
                {page_size, _} ->
                  Map.put(query_params, "page_size", page_size)

                :error ->
                  query_params
              end

            {key, val}, query_params ->
              Map.put(query_params, key, val)
          end)
    }

    new()
    |> put_page_size(conn.query_params)
    |> put_cursor_id(conn.query_params)
    |> put_page_number(conn.query_params)
    |> put_sort_direction(conn.query_params)
  end
end

defmodule PagingInputEctoTest do
  use ExUnit.Case
  doctest PagingInputEcto

  test "new give correct default" do
    paging_input = PagingInputEcto.new()

    assert paging_input.page_size == 8
    assert paging_input.cursor_id == nil
    assert paging_input.sort_direction == :desc
  end

  test "ensure page size in correct defined min and max range" do
    paging_input = PagingInputEcto.new()

    assert PagingInputEcto.put_page_size(paging_input, %{"page_size" => 69}).page_size == 32

    assert PagingInputEcto.put_page_size(paging_input, %{"page_size" => -2}).page_size == 8

    assert PagingInputEcto.put_page_size(paging_input, %{"page_size" => 16}).page_size == 16
  end

  test "ensure sort direction value set as desired" do
    paging_input = PagingInputEcto.new()

    paging_input = PagingInputEcto.put_sort_direction(paging_input, %{"sort_direction" => "asc"})

    assert paging_input.sort_direction == :asc

    assert PagingInputEcto.put_sort_direction(paging_input, %{"sort_direction" => "desc"}).sort_direction == :desc
  end

  test "ensure cursor_id value set as desired" do
    paging_input = PagingInputEcto.new()

    cursor_id = UUIDv7.autogenerate()

    assert PagingInputEcto.put_cursor_id(paging_input, %{"cursor_id" => "uuidv7:#{cursor_id}"}).cursor_id == cursor_id

    assert is_nil(PagingInputEcto.put_cursor_id(paging_input, %{"cursor_id" => 123_344}).cursor_id)

    assert is_nil(PagingInputEcto.put_cursor_id(paging_input, %{"cursor_id" => "uuidv7:ewfioewjf"}).cursor_id)

    assert is_nil(PagingInputEcto.put_cursor_id(paging_input, %{"cursor_id" => "integer:dfjklj"}).cursor_id)
  end

  test "able to parse query params from Plug.Conn" do
    paging_input = PagingInputEcto.from_conn(%Plug.Conn{query_params: %{
      "page_size" => "20",
      "cursor_id" => "uuidv7:#{UUIDv7.autogenerate()}",
      "sort_direction" => "asc"
    }})

    assert paging_input.page_size == 20
    assert not is_nil(paging_input.cursor_id)
    assert paging_input.sort_direction == :asc

    paging_input = PagingInputEcto.from_conn(%Plug.Conn{query_params: %{"sort_direction" => "desc", "page_size" => "df"}})

    assert paging_input.page_size == 8
    assert paging_input.sort_direction == :desc
  end

  test "able to apply ecto query correctly" do
    cursor_id = UUIDv7.autogenerate()

    paging_input =
      PagingInputEcto.new()
      |> PagingInputEcto.put_page_size(%{"page_size" => 16})
      |> PagingInputEcto.put_cursor_id(%{"cursor_id" => "uuidv7:#{cursor_id}"})
      |> PagingInputEcto.put_sort_direction(%{"sort_direction" => "desc"})

    assert "some_table_0" |> PagingInputEcto.apply_to_ecto_query(paging_input) |> Kernel.inspect() == "#Ecto.Query<from s0 in \"some_table_0\", where: s0.id < ^\"#{cursor_id}\", order_by: [desc: s0.id], limit: ^16>"

    cursor_id = "8"

    paging_input =
      paging_input
      |> PagingInputEcto.put_cursor_id(%{"cursor_id" => "integer:#{cursor_id}"})
      |> PagingInputEcto.put_sort_direction(%{"sort_direction" => "asc"})

    assert "some_table_1" |> PagingInputEcto.apply_to_ecto_query(paging_input) |> Kernel.inspect() == "#Ecto.Query<from s0 in \"some_table_1\", where: s0.id > ^#{cursor_id}, order_by: [asc: s0.id], limit: ^16>"

    assert PagingInputEcto.apply_to_ecto_query("some_table_2", PagingInputEcto.new()) |> Kernel.inspect() == "#Ecto.Query<from s0 in \"some_table_2\", order_by: [desc: s0.id], limit: ^8>"
  end
end

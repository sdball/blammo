defmodule BlammoWeb.LogsControllerTest do
  use BlammoWeb.ConnCase
  use Blammo.DataCase

  alias Blammo.DataCase, as: TestData

  test "GET /api/logs for test.log returns log lines in reverse order (newest first)", %{
    conn: conn
  } do
    conn = get(conn, ~p"/api/logs", %{filename: "test.log", lines: 10})

    expected =
      TestData.log_contents()
      |> Enum.reverse()
      |> Enum.join("\n")

    assert text_response(conn, 200) == expected <> "\n"
  end

  test "GET /api/logs/filter-first for test.log returns log lines in reverse order (newest first)",
       %{
         conn: conn
       } do
    conn = get(conn, ~p"/api/logs/filter-first", %{filename: "test.log", lines: 10})

    expected =
      TestData.log_contents()
      |> Enum.reverse()
      |> Enum.join("\n")

    assert text_response(conn, 200) == expected <> "\n"
  end

  test "GET /api/logs/filter-first for test.log filters file until it fulfills the limit or reads the entire file",
       %{
         conn: conn
       } do
    conn =
      get(conn, ~p"/api/logs/filter-first", %{filename: "test.log", lines: 2, filter: "line 1"})

    assert text_response(conn, 200) =~ "line 1\n"
  end

  test "GET /api/logs/filter-first with invalid params", %{conn: conn} do
    conn = get(conn, ~p"/api/logs/filter-first", %{})
    assert response(conn, 400)
  end

  test "GET /api/logs/tail-first for test.log returns log lines in reverse order (newest first)",
       %{
         conn: conn
       } do
    conn = get(conn, ~p"/api/logs/tail-first", %{filename: "test.log", lines: 10})

    expected =
      TestData.log_contents()
      |> Enum.reverse()
      |> Enum.join("\n")

    assert text_response(conn, 200) == expected <> "\n"
  end

  test "GET /api/logs/tail-first gets tail of file first and then filters",
       %{
         conn: conn
       } do
    conn =
      get(conn, ~p"/api/logs/tail-first", %{filename: "test.log", lines: 2, filter: "line 1"})

    # no result
    assert text_response(conn, 200) =~ ""
  end

  test "GET /api/logs/tail-first with invalid params", %{conn: conn} do
    conn = get(conn, ~p"/api/logs/tail-first", %{})
    assert response(conn, 400)
  end
end

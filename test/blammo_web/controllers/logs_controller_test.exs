defmodule BlammoWeb.LogsControllerTest do
  use BlammoWeb.ConnCase
  use Blammo.DataCase

  alias Blammo.DataCase, as: TestData

  test "GET /api/logs lists available log files", %{conn: conn} do
    conn = get(conn, ~p"/api/logs")
    assert json_response(conn, 200) |> Enum.any?(&(&1 == "test.log"))
  end

  test "GET /api/logs/tail for test.log returns log lines in reverse order (newest first)",
       %{
         conn: conn
       } do
    conn = get(conn, ~p"/api/logs/tail", %{filename: "test.log", lines: 10})

    expected =
      TestData.log_contents()
      |> Enum.reverse()
      |> Enum.join("\n")

    assert text_response(conn, 200) == expected <> "\n"
  end

  test "GET /api/logs/tail for test.log filters file until it fulfills the limit or reads the entire file",
       %{
         conn: conn
       } do
    conn =
      get(conn, ~p"/api/logs/tail", %{filename: "test.log", lines: 2, filter: "line 1"})

    assert text_response(conn, 200) =~ "line 1\n"
  end

  test "GET /api/logs/tail with invalid params", %{conn: conn} do
    conn = get(conn, ~p"/api/logs/tail", %{})
    assert response(conn, 400)
  end
end

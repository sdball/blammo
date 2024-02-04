defmodule BlammoWeb.LogsController do
  use BlammoWeb, :controller

  def tagline(conn, _params) do
    conn
    |> text("🪵  Log! From BLAMMO!\n")
  end
end

defmodule BlammoWeb.PageController do
  use BlammoWeb, :controller

  def home(conn, _params) do
    render(conn, :home, layout: false)
  end
end

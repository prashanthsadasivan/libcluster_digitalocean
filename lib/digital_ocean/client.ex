defmodule DigitalOcean.Client do
  def droplets(client) do
    get(client, "/droplets")
  end

  def droplets(client, tagname) do
    get(client, "/droplets?tag_name=#{tagname}")
  end

  # build dynamic client based on runtime arguments
  def new(token) do
    middleware = [
      {Tesla.Middleware.BaseUrl, "https://api.digitalocean.com/v2"},
      Tesla.Middleware.JSON,
      {Tesla.Middleware.Headers, [{"Authorization", "Bearer " <> token}]}
    ]

    Tesla.client(middleware)
  end

  defp get(client, url) do
    case Tesla.get(client, url) do
      {:ok, %Tesla.Env{body: body, status: 200}} -> {:ok, Map.get(body, "droplets")}
      other -> {:error, other}
    end
  end
end

defmodule Explorer.KnownTokens.Source.Database do
  @moduledoc """
  Adapter for fetching known tokens from Database
  """

  import Ecto.Query, only: [from: 2,]
  alias Explorer.Chain.Token
  alias Explorer.Repo

  @spec fetch_known_tokens() :: {:ok, [Hash.Address.t()]} | {:error, any}
  def fetch_known_tokens() do
    {:ok, from(token in Token,
        distinct: token.holder_count,
        select: %{
          symbol: token.symbol,
          holder_count: token.holder_count,
          address: fragment("'0x'||encode(?, 'hex')", token.contract_address_hash)
        },
        order_by: [desc: token.holder_count, asc: token.symbol]
      ) |> Repo.all() |> Enum.map(fn x -> Map.new(x, fn {key, value} -> {to_string(key), value} end) end)
    }
  end
end

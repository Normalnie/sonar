defmodule Explorer.ENS.NameRetriever do
  @moduledoc """
  Retrieves ENS Domain Name from registry using Smart Contract functions from the blockchain.
  """

  require Logger

  alias Explorer.{Chain, Repo}
  alias Explorer.Chain.{Hash, Token}
  alias Explorer.SmartContract.Reader

  @regex ~r/^((.*)\.)?([^.]+)$/
  def namehash(name) do
    namehash(String.downcase(name), <<0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0>>)
  end
  defp namehash(name, hash) do
    case byte_size(name) do
      0 -> hash
      _ ->
        partition = Regex.run(@regex, name)
        case partition do
          nil -> {:error, "Invalid ENS name"}
          matches ->
            [rest, label] = [Enum.at(matches, 2), Enum.at(matches,3)]
            new_hash = ExKeccak.hash_256(hash <> ExKeccak.hash_256(label))
            case byte_size(rest) do
              0 -> new_hash
              _ -> namehash(rest, new_hash)
            end
        end
    end
  end

  @registry_abi [
    %{
      "inputs" => [
        %{
          "internalType" => "bytes32",
          "name" => "node",
          "type" => "bytes32"
        }
      ],
      "name" => "resolver",
      "outputs" => [
        %{
          "internalType" => "address",
          "name" => "",
          "type" => "address"
        }
      ],
      "stateMutability" => "view",
      "type" => "function"
    },
  ]
  # 0178b8bf = keccak256(resolver(bytes32))
  @resolver_function "0178b8bf"

  @resolver_abi [
    %{
      "inputs" => [
        %{
          "internalType" => "bytes32",
          "name" => "node",
          "type" => "bytes32"
        }
      ],
      "name" => "name",
      "outputs" => [
        %{
          "internalType" => "string",
          "name" => "",
          "type" => "string"
        }
      ],
      "stateMutability" => "view",
      "type" => "function"
    },
  ]
  # 691f3431 = keccak256(name(bytes32))
  @name_function "691f3431"

  @registry_address "0xcfb86556760d03942ebf1ba88a9870e67d77b627"

  def fetch_resolver_of(address) do
    reverse_address = String.downcase(String.slice(address, 2..-1)) <> ".addr.reverse"
    reverse_address_hash = namehash(reverse_address)
    reverse_address_hash_str = Base.encode16(reverse_address_hash, case: :lower)

    contract_functions = %{@resolver_function => ["0x"<>reverse_address_hash_str]}

    @registry_address
    |> query_contract(contract_functions, @registry_abi)
    |> handle_resolver_result()
  end

  def fetch_name_of(address) do
    reverse_address = String.downcase(String.slice(address, 2..-1)) <> ".addr.reverse"
    reverse_address_hash = namehash(reverse_address)

    registrar_functions = %{@resolver_function => [reverse_address_hash]}

    resolver_result = @registry_address
    |> query_contract(registrar_functions, @registry_abi)
    |> handle_resolver_result()
    # resolver_result = {:ok, "0x1ba19b976fefc1c9c684f2b821e494a380f45a0f"}

    case resolver_result do
      {:error, error} -> {:error, error}
      {:ok, resolver_address} ->
        resolver_functions = %{@name_function => [reverse_address_hash]}

        name = resolver_address
        |> query_contract(resolver_functions, @resolver_abi)
        |> handle_name_result()
    end
  end

  def handle_resolver_result(%{@resolver_function => {:ok, [resolver_address_str]}}) do
    case resolver_address_str do
      "0x0000000000000000000000000000000000000000" -> {:error, "ENS resolver not set for reverse registrar"}
      _ -> {:ok, resolver_address_str}
    end
  end

  def handle_resolver_result(%{@resolver_function => {:error, error}}) do
    {:error, error}
  end

  def handle_name_result(%{@name_function => {:ok, [name]}}) do
    case byte_size(name) do
      0 -> {:error, "ENS name not found"}
      _ ->
        case name do
          "0x0000000000000000000000000000000000000000" -> {:error, "Primary ENS name was unset"}
          _ ->
            {:ok, handle_large_string(name)}
        end
    end
  end

  def handle_name_result(%{@name_function => {:error, error}}) do
    {:error, error}
  end

  def query_contract(contract_address, contract_functions, abi) do
    Reader.query_contract(contract_address, abi, contract_functions, true)
  end

  defp handle_large_string(nil), do: nil
  defp handle_large_string(string), do: handle_large_string(string, byte_size(string))
  defp handle_large_string(string, size) when size > 255, do: shorten_to_valid_utf(binary_part(string, 0, 255))
  defp handle_large_string(string, _size), do: string

  defp remove_null_bytes(string) do
    String.replace(string, "\0", "")
  end

  def shorten_to_valid_utf(string) do
    case String.valid?(string) do
      true  -> string
      false -> shorten_to_valid_utf(binary_part(string, 0, byte_size(string) - 1))
    end
  end
end

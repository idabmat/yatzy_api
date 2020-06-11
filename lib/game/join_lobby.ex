defmodule Game.JoinLobby do
  @moduledoc """
  Joining an existing lobby
  """

  alias Auth.Account
  alias Ecto.Changeset
  alias Game.Lobby
  alias Game.Player

  @type args :: %{lobby_id: String.t(), player_name: String.t(), account_id: String.t()}
  @type errors :: [lobby: [atom()], player: [atom()]]
  @type gateways :: [lobby_gateway: module(), account_gateway: module()]
  @type response :: :ok | {:error, errors()}

  @spec execute(args(), gateways()) :: response()
  def execute(%{lobby_id: lobby_id, player_name: player_name, account_id: account_id}, gateways) do
    account = get_resource(account_id, gateways[:account_gateway])
    lobby = get_resource(lobby_id, gateways[:lobby_gateway])

    case validate(%{lobby: lobby, account: account, player_name: player_name}) do
      [] ->
        player = %Player{name: player_name, account_id: account_id}
        updated_lobby = %Lobby{lobby | players: [player | lobby.players]}
        insert_player(updated_lobby, gateways[:lobby_gateway])

      errors ->
        {:error, errors}
    end
  end

  defp get_resource(resource_id, resource_gateway) do
    resource_gateway.get(resource_id)
  end

  @spec validate(%{lobby: nil | Lobby.t(), account: nil | Account.t(), player_name: String.t()}) ::
          keyword([atom()])
  defp validate(params) do
    data = %{}
    types = %{lobby: :map, account: :map, player_name: :string}

    {data, types}
    |> Changeset.cast(params, Map.keys(types))
    |> Changeset.validate_required(:player_name, message: :must_have_name)
    |> Changeset.validate_required([:lobby, :account], message: :not_found)
    |> Map.get(:errors, [])
    |> Enum.map(&rename_error_keys/1)
    |> Enum.reduce([], &merge_error_keys/2)
  end

  defp rename_error_keys({:lobby, {error, _validations}}), do: {:lobby, error}
  defp rename_error_keys({_field, {error, _validations}}), do: {:player, error}

  defp merge_error_keys({field, error}, errors) do
    Keyword.update(errors, field, [error], &(&1 ++ [error]))
  end

  defp insert_player(lobby, lobby_gateway) do
    case lobby_gateway.set(lobby) do
      :ok -> :ok
      {:error, :duplicate_account} -> {:error, [player: [:already_joined]]}
      {:error, :duplicate_name} -> {:error, [player: [:name_taken]]}
    end
  end
end

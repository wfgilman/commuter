defmodule ApiWeb.ErrorHelpers do
  @moduledoc """
  Conveniences for translating and building error messages.
  """

  @doc """
  Translates an error message using gettext.
  """
  def translate_error({msg, opts}) do
    # When using gettext, we typically pass the strings we want
    # to translate as a static argument:
    #
    #     # Translate "is invalid" in the "errors" domain
    #     dgettext("errors", "is invalid")
    #
    #     # Translate the number of files with plural rules
    #     dngettext("errors", "1 file", "%{count} files", count)
    #
    # Because the error messages we show in our forms and APIs
    # are defined inside Ecto, we need to translate them dynamically.
    # This requires us to call the Gettext module passing our gettext
    # backend as first argument.
    #
    # Note we use the "errors" domain, which means translations
    # should be written to the errors.po file. The :count option is
    # set by Ecto and indicates we should also apply plural rules.
    if count = opts[:count] do
      Gettext.dngettext(ApiWeb.Gettext, "errors", msg, msg, count, opts)
    else
      Gettext.dgettext(ApiWeb.Gettext, "errors", msg, opts)
    end
  end

  def error_string_from_changeset(changeset) do
    changeset
    |> merge_nested_errors()
    |> Enum.map(fn {k, v} -> "#{Phoenix.Naming.humanize(k)} #{translate_error(v)}" end)
    |> Enum.join(". ")
    |> Kernel.<>(".")
  end

  defp merge_nested_errors(%Ecto.Changeset{changes: changes} = changeset) do
    changes
    |> Map.to_list()
    |> Enum.map(fn
      {_k, %Ecto.Changeset{errors: errors}} ->
        errors

      {_k, [%Ecto.Changeset{errors: errors}]} ->
        errors

      _ ->
        nil
    end)
    |> Enum.reject(&is_nil/1)
    |> List.flatten()
    |> Kernel.++(changeset.errors)
  end
end

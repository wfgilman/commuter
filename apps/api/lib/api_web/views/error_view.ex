defmodule ApiWeb.ErrorView do
  use ApiWeb, :view

  def render("404.json", %{message: message}) do
    %{
      code: "not_found_error",
      message: message
    }
  end

  def render("404.json", _assigns) do
    %{
      code: "not_found_error",
      message: "We couldn't find the resource your requested."
    }
  end

  def render("500.json", _assigns) do
    %{
      code: "api_error",
      message: "Your request couldn't be processed."
    }
  end

  def render("query_params.json", _assigns) do
    %{
      code: "invalid_request_error",
      message: "The query parameters you specified are invalid."
    }
  end

  def render("changeset.json", %{data: %Ecto.Changeset{} = changeset}) do
    %{
      code: "validation_error",
      message: ApiWeb.ErrorHelpers.error_string_from_changeset(changeset)
    }
  end

  def template_not_found(template, _assigns) do
    %{
      code: "template_not_found",
      message: Phoenix.Controller.status_message_from_template(template)
    }
  end
end

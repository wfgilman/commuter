defmodule Core.Service do
  import Ecto.Query
  import Shared.Utils

  @start_of_service_hour 3

  def current_services do
    holiday =
      Db.Repo.one(
        from(s in Db.Model.Service,
          join: se in assoc(s, :service_exception),
          where: se.date == ^today()
        )
      )

    if not is_nil(holiday) do
      holiday
    else
      derive_current_services()
    end
  end

  def derive_current_services do
    day_of_week = Date.day_of_week(today())
    current_time = now()
    {:ok, start_of_service} = Time.new(@start_of_service_hour, 0, 0)

    current_service_day_of_week =
      cond do
        Time.compare(current_time, start_of_service) == :lt ->
          if day_of_week == 1 do
            7
          else
            day_of_week - 1
          end

        true ->
          day_of_week
      end

    constraint = weekday_constraint(current_service_day_of_week)

    Db.Repo.all(
      from(s in Db.Model.Service,
        join: sc in assoc(s, :service_calendar),
        where: ^constraint,
        where: sc.date_effective <= ^today()
      )
    )
  end

  def weekday_constraint(1), do: dynamic([_s, sc], sc.mon == true)
  def weekday_constraint(2), do: dynamic([_s, sc], sc.tue == true)
  def weekday_constraint(3), do: dynamic([_s, sc], sc.wed == true)
  def weekday_constraint(4), do: dynamic([_s, sc], sc.thu == true)
  def weekday_constraint(5), do: dynamic([_s, sc], sc.fri == true)
  def weekday_constraint(6), do: dynamic([_s, sc], sc.sat == true)
  def weekday_constraint(7), do: dynamic([_s, sc], sc.sun == true)
end

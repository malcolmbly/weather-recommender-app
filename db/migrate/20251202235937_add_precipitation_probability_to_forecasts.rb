class AddPrecipitationProbabilityToForecasts < ActiveRecord::Migration[8.1]
  def change
    add_column :forecasts, :precipitation_probability, :float
  end
end

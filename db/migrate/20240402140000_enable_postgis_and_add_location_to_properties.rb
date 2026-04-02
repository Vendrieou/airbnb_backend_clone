class EnablePostgis < ActiveRecord::Migration[7.0]
  def change
    enable_extension 'postgis' unless extension_enabled?('postgis')
    
    add_column :properties, :latitude, :decimal, precision: 10, scale: 8
    add_column :properties, :longitude, :decimal, precision: 11, scale: 8
    add_column :properties, :location, :st_point, geographic: true
    
    add_index :properties, :location, using: :gist
    add_index :properties, [:latitude, :longitude]
  end
end

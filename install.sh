#!/usr/bin/env sh
# Setup the LIMS logic for Baobab Health Trust OpenMRS based EMRs

echo "Enter target project root folder path [../National-ART/]:"

read path

if [ -z "$path" ]; then path="../National-ART/"; fi;

old_path=`pwd`

echo "Enter the LIMS repo connection protocol [http]:"

read protocol

if [ -z "$protocol" ]; then protocol="http"; fi;

echo "Enter the LIMS repo connection host [localhost]:"

read host

if [ -z "$host" ]; then host="localhost"; fi;

echo "Enter the LIMS repo connection port [3014]:"

read port

if [ -z "$port" ]; then port="3014"; fi;

echo "Enter facility district [Lilongwe]:"

read district

if [ -z "$district" ]; then district="Lilongwe"; fi;

echo "Enter facility name [Kamuzu (KCH) Central Hospital]:"

read facility

if [ -z "$facility" ]; then facility="Kamuzu (KCH) Central Hospital"; fi;

echo "development:\n  protocol: $protocol\n  host: $host\n  port: $port\n  order_path: /lab_order?hide_demographics=true&return_path=\n  query_path: /query_results/\n  district: $district\n  health_facility_name: $facility\n\ntest:\n  <<: *development\n\nproduction:\n  <<: *development" > "${path}config/lims.yml"

sed -i -e 's/map\.root\s\:controller\s=>\s"dde"/map.root :controller => "dde"\n\tmap.connect "lims\/query\/:id", :controller => "lims", :action => "query"\n\n\tmap.connect "lims\/general\/", :controller => "lims", :action => "general"\n\n\tmap.connect "lims\/create\/", :controller => "lims", :action => "create"\n\n\tmap.connect "lims\/fetch_results\/:id", :controller => "lims", :action => "fetch_results"\n\n\tmap.connect "lims\/show\/:id", :controller => "lims", :action => "show"\n\n\tmap.connect "\/sample_tests\/:id", :controller => "lims", :action => "sample_tests"\n\n\tmap.connect "lims\/:id", :controller => "lims", :action => "index"\n\n\tmap.connect "custom_sample_tests\/:id", :controller => "lims", :action => "custom_sample_tests"\n\n\tmap.connect "\/lab\/view", :controller => "lims", :action => "generic_view"\n\n\tmap.connect "\/lab\/graph", :controller => "lims", :action => "generic_graph"\n\n\tmap.connect "\/lab\/results\/:id", :controller => "lims", :action => "generic_results"\n\n\tmap.connect "\/charts\/series", :controller => "lims", :action => "generic_series"\n/' "${path}config/routes.rb"

cp -r library/ "${path}public/"

cp ./lims_controller.rb "${path}app/controllers/"

if [ -e "${path}app/controllers/encounter_types_controller.rb" ]; 
then 
	
	sed -i -e 's/def\sshow/def show\n\t\tif params["encounter_type"].downcase == "lab orders"\n\n\t\t\tredirect_to "\/lims?id=#{params[:patient_id]}\&location_id=#{session[:location_id]}\&user_id=#{User.current.id rescue nil}" and return\n\n\t\tend\n/' "${path}app/controllers/encounter_types_controller.rb"
	
fi;


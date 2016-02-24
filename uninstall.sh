#!/usr/bin/env sh
# Uninstall the LIMS logic for Baobab Health Trust OpenMRS based EMRs

echo "Enter target project root folder path [../National-ART/]:"

read path

if [ -z "$path" ]; then path="../National-ART/"; fi;

sed -i -e '/map\.connect\s"lims\/query\/\:id",\s:controller\s=>\s"lims",\s\:action\s=>\s"query"/,+15d' "${path}config/routes.rb"

# sed -i -e 's/map\.connect\s"lims\/general\/",\s:controller\s=>\s"lims",\s\:action\s=>\s"general"//' "${path}config/routes.rb"

# sed -i -e 's/map\.connect\s"lims\/create\/",\s:controller\s=>\s"lims",\s\:action\s=>\s"create"//' "${path}config/routes.rb"

# sed -i -e 's/map\.connect\s"lims\/fetch\_results\/\:id",\s:controller\s=>\s"lims",\s\:action\s=>\s"fetch\_results"//' "${path}config/routes.rb"

# sed -i -e 's/map\.connect\s"lims\/show\/\:id",\s:controller\s=>\s"lims",\s\:action\s=>\s"show"//' "${path}config/routes.rb"

# sed -i -e 's/map\.connect\s"lims\/sample_tests\/\:id",\s:controller\s=>\s"lims",\s\:action\s=>\s"sample_tests"//' "${path}config/routes.rb"

# sed -i -e 's/map\.connect\s"lims\/\:id",\s:controller\s=>\s"lims",\s\:action\s=>\s"index"//' "${path}config/routes.rb"

# sed -i -e 's/map\.connect\s"\/sample\_tests\/\:id",\s:controller\s=>\s"lims",\s\:action\s=>\s"sample_tests"//' "${path}config/routes.rb"

# sed -i -e 's/map\.connect\s"custom\_sample\_tests\/\:id",\s:controller\s=>\s"lims",\s\:action\s=>\s"custom\_sample\_tests"//' "${path}config/routes.rb"

rm -rf "${path}config/lims.yml"

rm -rf "${path}/public/library"

rm "${path}app/controllers/lims_controller.rb"

if [ -e "${path}app/controllers/encounter_types_controller.rb" ]; 
then 
	
	sed -i -e '/if\sparams\["encounter\_type"\]\.downcase\s==\s"lab\sorders"/,+4d' "${path}app/controllers/encounter_types_controller.rb"

fi;

# if [ -e "${path}config/environment.rb" ]; 
# then 
	
#	cd "${path}"
	
#	bundle console
	
#	ruby -r"${path}config/environment.rb" -e 'a = GlobalProperty.find_by_property("encounter_privilege_map").property_value.split(","); a.delete("Order Lab Test(s):LAB ORDERS"); GlobalProperty.find_by_property("encounter_privilege_map").update_attribute(:property_value, a.join(","))'
	
#	cd $old_path
	
#	echo "Updated tasks' list"; 
	
# fi;



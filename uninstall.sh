#!/usr/bin/env sh
# Uninstall the LIMS logic for Baobab Health Trust OpenMRS based EMRs

echo "Enter target project root folder path [../National-ART/]:"

read path

if [ -z "$path" ]; then path="../National-ART/"; fi;

sed -i -e '/map\.connect\s"lims\/query\/\:id",\s:controller\s=>\s"lims",\s\:action\s=>\s"query"/,+23d' "${path}config/routes.rb"

rm -rf "${path}config/lims.yml"

rm -rf "${path}/public/library"

rm "${path}app/controllers/lims_controller.rb"

if [ -e "${path}app/controllers/encounter_types_controller.rb" ]; 
then 
	
	sed -i -e '/if\sparams\["encounter\_type"\]\.downcase\s==\s"lab\sorders"/,+4d' "${path}app/controllers/encounter_types_controller.rb"

fi;



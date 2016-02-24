require 'net/http'
require 'uri'
require 'rest-client'
require 'json'

class LimsController < ApplicationController

  def open(url)
    Net::HTTP.get(URI.parse(url))
  end

  def index

    if params[:id].blank? or params[:location_id].blank? or params[:user_id].blank?

      missing_fields = []

      if params[:id].blank?

        missing_fields << :id

      end

      if params[:location_id].blank?

        missing_fields << :location_id

      end

      if params[:user_id].blank?

        missing_fields << :user_id

      end

      raise "Missing required fields in the sent request: #{missing_fields.inspect}"

    end

    user = User.find(params[:user_id]) rescue nil

    raise "User not found" if user.blank?

    user_demo = PersonName.find(user.person_id) rescue nil

    params[:collector_first_name] = user_demo.given_name rescue nil

    params[:collector_last_name] = user_demo.family_name rescue nil

    params[:collector_id] = user.username rescue nil

    user_phone = PersonAttribute.find_by_person_id_and_person_attribute_type_id(user.person_id,
                                                                                (PersonAttributeType.find_by_name('Cell Phone Number').id rescue nil)) rescue nil

    params[:collector_phone_number] = user_phone

    person = Person.find(params[:id]) rescue nil

    identifier = PatientIdentifier.find_by_patient_id(person.person_id) rescue nil

    patient = {}

    if identifier and person

      patient_id = identifier.patient_id

      patient['national_patient_id'] = identifier.identifier

      name = PersonName.find_by_person_id(patient_id) rescue nil

      phone = PersonAttribute.find_by_person_id_and_person_attribute_type_id(patient_id,
                                                                             (PersonAttributeType.find_by_name('Cell Phone Number').id rescue nil)) rescue nil

      if name

        patient['first_name'] = name.given_name

        patient['last_name'] = name.family_name

        patient['middle_name'] = name.middle_name

      end

      if person

        patient['date_of_birth'] = (person.birthdate.to_date.strftime("%a %b %d %Y")) rescue nil

        patient['gender'] = person.gender rescue nil

      end

      if phone

        patient['phone_number'] = phone.value rescue nil

      end

    end

    patient['order_location'] = Location.find(params[:location_id]).name rescue nil;

    settings = YAML.load_file("#{Rails.root}/config/lims.yml")[Rails.env]

    url = "#{settings['protocol']}://#{settings['host']}:#{settings['port']}#{settings['order_path']}#{request.protocol}" +
        "#{request.host_with_port}/lims/create&sample_collector_first_name=#{params[:collector_first_name]}&" +
        "sample_collector_last_name=#{params[:collector_last_name]}&sample_collector_phone_number=#{params[:collector_phone_number]}&" +
        "sample_collector_id=#{params[:collector_id]}&sample_order_location=#{patient['order_location'].gsub(/\s/, '+')}&" +
        "district=#{settings['district'].gsub(/\s/, '+')}&health_facility_name=#{settings['health_facility_name'].gsub(/\s/, '+')}&" +
        "first_name=#{patient['first_name']}&last_name=#{patient['last_name']}&middle_name=#{patient['middle_name']}&" +
        "date_of_birth=#{patient['date_of_birth'].gsub(/\s/, '+')}&gender=#{patient['gender']}&" +
        "national_patient_id=#{patient['national_patient_id']}&phone_number=#{patient['phone_number']}&ts=true"

    @page_content = open(url)

    # @page_content = @page_content.gsub(/action="\/create_hl7_order"/,
    #                                   "action='#{settings['protocol']}://#{settings['host']}:#{settings['port']}/create_hl7_order'")

    @page_content = @page_content.gsub(/remoteSearchURL\s=\s"\/query_order\/"/,
                                       "remoteSearchURL = '#{settings['protocol']}://#{settings['host']}:#{settings['port']}/query_results/'")

    @page_content = @page_content.gsub(/localSearchURL\s=\s"http\:\/\/localhost\/chai\/test\/query.php\?id\="/,
                                       "localSearchURL = '/lims/query/'")

    @page_content = @page_content.gsub(/localCreateURL\s=\s"http\:\/\/localhost\/chai\/test\/create.php"/,
                                       "localCreateURL = '/lims/create/'")

    @page_content = @page_content.gsub(/localQueryURL\s=\s"http\:\/\/localhost\/chai\/test\/query.php"/,
                                       "localQueryURL = '/lims/query/'")

    @page_content = @page_content.gsub(/localViewOnlyURL\s=\s"http\:\/\/localhost\:3000\/lims\/show\/"/,
                                       "localViewOnlyURL = '/lims/show/'")

    @page_content = @page_content.gsub(/\/create\_hl7\_order/,
                                       "#{settings['protocol']}://#{settings['host']}:#{settings['port']}/create_hl7_order")

    @page_content = @page_content.gsub(/tt\_cancel\_destination\s=\s"\/patients\/show\/"/,
                                       "tt_cancel_destination = '/patients/show/#{params[:id]}&user_id=#{params[:user_id]}'")

    render :text => @page_content
  end

  def do_query(id)

    result = {}

    order = Order.find_by_accession_number(id) rescue nil

    return result if !order

    encounter = Encounter.find(order.encounter_id) rescue nil

    order_location = Location.find(encounter.location_id).name rescue nil

    order_type_id = OrderType.find_by_name("Lab").order_type_id rescue nil

    order_concept_id = ConceptName.find_by_name("Laboratory tests ordered").concept_id rescue nil

    sample_type_concept_id = ConceptName.find_by_name("Sample").concept_id rescue nil

    sample_status_concept_id = ConceptName.find_by_name("Status").concept_id rescue nil

    who_updated_first_name_concept_id = ConceptName.find_by_name("Given name").concept_id rescue nil

    who_updated_last_name_concept_id = ConceptName.find_by_name("Family name").concept_id rescue nil

    who_updated_phone_number_concept_id = ConceptName.find_by_name("Phone number").concept_id rescue nil

    who_updated_health_facility_concept_id = ConceptName.find_by_name("Health facility name").concept_id rescue nil

    who_updated_id_number_concept_id = ConceptName.find_by_name("Name of doctor").concept_id rescue nil

    remarks_concept_id = ConceptName.find_by_name("Comments").concept_id rescue nil

    lab_result_concept_id = ConceptName.find_by_name("Lab test result").concept_id rescue nil

    lab_result_value_concept_id = ConceptName.find_by_name("Given lab results").concept_id rescue nil

    art_start_date_concept_id = ConceptName.find_by_name("ART start date").concept_id rescue nil

    date_received_concept_id = ConceptName.find_by_name("Date received").concept_id rescue nil

    date_dispatched_concept_id = ConceptName.find_by_name("Date collected").concept_id rescue nil

    receiving_facility_concept_id = ConceptName.find_by_name("Health facility name").concept_id rescue nil

    sending_facility_concept_id = ConceptName.find_by_name("Source").concept_id rescue nil

    datetime_started_concept_id = ConceptName.find_by_name("Start date").concept_id rescue nil

    date_completed_concept_id = ConceptName.find_by_name("Completed").concept_id rescue nil

    date_drawn_concept_id = ConceptName.find_by_name("Date specimen received").concept_id rescue nil

    priority_concept_id = ConceptName.find_by_name("Indicated urgently").concept_id rescue nil

    reason_for_test_concept_id = ConceptName.find_by_name("Reason for test").concept_id rescue nil

    district_concept_id = ConceptName.find_by_name("District").concept_id rescue nil

    art_start_date =
        Observation.find_by_concept_id_and_encounter_id_and_order_id_and_accession_number(art_start_date_concept_id,
                                                                                          order.encounter_id,
                                                                                          order.order_id,
                                                                                          order.accession_number
        ).value_datetime.to_time.strftime("%Y-%m-%d %H:%S") rescue nil

    test_types = []

    test_results = {}

    Observation.all(:conditions => ["concept_id = ? AND encounter_id = ? AND order_id = ? AND accession_number = ?",
                                    order_concept_id,
                                    order.encounter_id,
                                    order.order_id,
                                    order.accession_number]).each do |obs|

      test_types << obs.value_text # if not test_types.include?(obs.value_text)

      test_status = Observation.find_by_concept_id_and_encounter_id_and_order_id_and_obs_group_id_and_accession_number(sample_status_concept_id,
                                                                                                                       order.encounter_id,
                                                                                                                       order.order_id,
                                                                                                                       obs.obs_id,
                                                                                                                       order.accession_number
      ).value_text rescue nil

      remarks = Observation.find_by_concept_id_and_encounter_id_and_order_id_and_obs_group_id_and_accession_number(remarks_concept_id,
                                                                                                                   order.encounter_id,
                                                                                                                   order.order_id,
                                                                                                                   obs.obs_id,
                                                                                                                   order.accession_number
      ).value_text rescue nil

      date_started = Observation.find_by_concept_id_and_encounter_id_and_order_id_and_obs_group_id_and_accession_number(datetime_started_concept_id,
                                                                                                                        order.encounter_id,
                                                                                                                        order.order_id,
                                                                                                                        obs.obs_id,
                                                                                                                        order.accession_number
      ).value_datetime.to_time.strftime("%Y-%m-%d %H:%S") rescue nil

      date_completed = Observation.find_by_concept_id_and_encounter_id_and_order_id_and_obs_group_id_and_accession_number(date_completed_concept_id,
                                                                                                                          order.encounter_id,
                                                                                                                          order.order_id,
                                                                                                                          obs.obs_id,
                                                                                                                          order.accession_number
      ).value_datetime.to_time.strftime("%Y-%m-%d %H:%S") rescue nil

      wu_fname = Observation.find_by_concept_id_and_encounter_id_and_order_id_and_obs_group_id_and_accession_number(who_updated_first_name_concept_id,
                                                                                                                    order.encounter_id,
                                                                                                                    order.order_id,
                                                                                                                    obs.obs_id,
                                                                                                                    order.accession_number
      ).value_text rescue nil

      wu_lname = Observation.find_by_concept_id_and_encounter_id_and_order_id_and_obs_group_id_and_accession_number(who_updated_last_name_concept_id,
                                                                                                                    order.encounter_id,
                                                                                                                    order.order_id,
                                                                                                                    obs.obs_id,
                                                                                                                    order.accession_number
      ).value_text rescue nil

      wu_id = Observation.find_by_concept_id_and_encounter_id_and_order_id_and_obs_group_id_and_accession_number(who_updated_id_number_concept_id,
                                                                                                                 order.encounter_id,
                                                                                                                 order.order_id,
                                                                                                                 obs.obs_id,
                                                                                                                 order.accession_number
      ).value_text rescue nil

      wu_phone = Observation.find_by_concept_id_and_encounter_id_and_order_id_and_obs_group_id_and_accession_number(who_updated_phone_number_concept_id,
                                                                                                                    order.encounter_id,
                                                                                                                    order.order_id,
                                                                                                                    obs.obs_id,
                                                                                                                    order.accession_number
      ).value_text rescue nil

      wu_facility = Observation.find_by_concept_id_and_encounter_id_and_order_id_and_obs_group_id_and_accession_number(who_updated_health_facility_concept_id,
                                                                                                                       order.encounter_id,
                                                                                                                       order.order_id,
                                                                                                                       obs.obs_id,
                                                                                                                       order.accession_number
      ).value_text rescue nil

      test_results[obs.value_text] = {
          "test_status" => test_status,
          "remarks" => remarks,
          "datetime_started" => date_started,
          "datetime_completed" => date_completed,
          "who_updated" => {
              "first_name" => wu_fname,
              "last_name" => wu_lname,
              "ID_number" => wu_id,
              "phone_number" => wu_phone,
              "facility" => wu_facility
          },
          "results" => {}
      }

      Observation.all(:conditions => ["concept_id = ? AND encounter_id = ? AND order_id = ? AND obs_group_id = ? AND accession_number = ?",
                                      lab_result_concept_id, order.encounter_id,
                                      order.order_id,
                                      obs.obs_id,
                                      order.accession_number]).each do |result|

        lab_test = result.value_text

        lab_result = Observation.find_by_concept_id_and_encounter_id_and_order_id_and_obs_group_id_and_accession_number(lab_result_value_concept_id,
                                                                                                                        order.encounter_id,
                                                                                                                        order.order_id,
                                                                                                                        result.obs_id,
                                                                                                                        order.accession_number
        ).value_text rescue nil

        test_results[obs.value_text]["results"][lab_test] = lab_result

      end

    end

    date_received =
        Observation.find_by_concept_id_and_encounter_id_and_order_id_and_accession_number(date_received_concept_id,
                                                                                          order.encounter_id,
                                                                                          order.order_id,
                                                                                          order.accession_number
        ).value_datetime.to_time.strftime("%Y-%m-%d %H:%S") rescue nil

    who_order_test_id_number = User.find(encounter.provider_id).username rescue nil

    who_ordered_test_name = PersonName.find_by_person_id(encounter.provider_id) rescue nil

    who_ordered_test_fname = who_ordered_test_name.given_name rescue nil

    who_ordered_test_lname = who_ordered_test_name.family_name rescue nil

    who_ordered_test_phone = PersonAttribute.find_by_person_id_and_person_attribute_type_id(encounter.provider_id,
                                                                                            (PersonAttributeType.find_by_name('Cell Phone Number').id rescue nil)).value rescue nil

    date_time = encounter.encounter_datetime.to_time.strftime("%Y-%m-%d %H:%S") rescue nil

    date_dispatched =
        Observation.find_by_concept_id_and_encounter_id_and_order_id_and_accession_number(date_dispatched_concept_id,
                                                                                          order.encounter_id,
                                                                                          order.order_id,
                                                                                          order.accession_number
        ).value_datetime.to_time.strftime("%Y-%m-%d %H:%S") rescue nil

    sending_facility =
        Observation.find_by_concept_id_and_encounter_id_and_order_id_and_accession_number(sending_facility_concept_id,
                                                                                          order.encounter_id,
                                                                                          order.order_id,
                                                                                          order.accession_number
        ).value_text rescue nil

    priority =
        Observation.find_by_concept_id_and_encounter_id_and_order_id_and_accession_number(priority_concept_id,
                                                                                          order.encounter_id,
                                                                                          order.order_id,
                                                                                          order.accession_number
        ).value_text rescue nil

    sample_status =
        Observation.find_by_concept_id_and_encounter_id_and_order_id_and_accession_number(sample_status_concept_id,
                                                                                          order.encounter_id,
                                                                                          order.order_id,
                                                                                          order.accession_number
        ).value_text rescue nil

    reason_for_test =
        Observation.find_by_concept_id_and_encounter_id_and_order_id_and_accession_number(reason_for_test_concept_id,
                                                                                          order.encounter_id,
                                                                                          order.order_id,
                                                                                          order.accession_number
        ).value_text rescue nil

    receiving_facility =
        Observation.find_by_concept_id_and_encounter_id_and_order_id_and_accession_number(receiving_facility_concept_id,
                                                                                          order.encounter_id,
                                                                                          order.order_id,
                                                                                          order.accession_number
        ).value_text rescue nil

    date_drawn =
        Observation.find_by_concept_id_and_encounter_id_and_order_id_and_accession_number(date_drawn_concept_id,
                                                                                          order.encounter_id,
                                                                                          order.order_id,
                                                                                          order.accession_number
        ).value_datetime.to_time.strftime("%Y-%m-%d %H:%S") rescue nil

    sample_type =
        Observation.find_by_concept_id_and_encounter_id_and_order_id_and_accession_number(sample_type_concept_id,
                                                                                          order.encounter_id,
                                                                                          order.order_id,
                                                                                          order.accession_number
        ).value_text rescue nil

    district =
        Observation.find_by_concept_id_and_encounter_id_and_order_id_and_accession_number(district_concept_id,
                                                                                          order.encounter_id,
                                                                                          order.order_id,
                                                                                          order.accession_number
        ).value_text rescue nil

    patient_national_id = PatientIdentifier.find_by_patient_id_and_identifier_type(encounter.patient_id,
                                                                                   PatientIdentifierType.find_by_name("National id").id).identifier rescue nil

    date_of_birth = Person.find(encounter.patient_id).birthdate.to_date.strftime("%Y-%m-%d") rescue nil

    gender = Person.find(encounter.patient_id).gender rescue nil

    name = PersonName.find_by_person_id(encounter.patient_id) rescue nil

    phone_number = PersonAttribute.find_by_person_id_and_person_attribute_type_id(encounter.patient_id,
                                                                                  (PersonAttributeType.find_by_name('Cell Phone Number').id rescue nil)).value rescue nil

    result = {
        "order_location" => order_location,
        "art_start_date" => art_start_date,
        "accession_number" => (order.accession_number rescue nil),
        "test_types" => test_types,
        "date_received" => date_received,
        "results" => test_results,
        "district" => district,
        "who_order_test" => {
            "id_number" => who_order_test_id_number,
            "first_name" => who_ordered_test_fname,
            "phone_number" => who_ordered_test_phone,
            "last_name" => who_ordered_test_lname
        },
        "date_time" => date_time,
        "date_dispatched" => date_dispatched,
        "_id" => (order.accession_number rescue nil),
        "sending_facility" => sending_facility,
        "priority" => priority,
        "status" => sample_status,
        "reason_for_test" => reason_for_test,
        "receiving_facility" => receiving_facility,
        "date_drawn" => date_drawn,
        "sample_type" => sample_type,
        "patient" => {
            "national_patient_id" => patient_national_id,
            "date_of_birth" => date_of_birth,
            "middle_name" => (name.middle_name rescue nil),
            "first_name" => (name.given_name rescue nil),
            "phone_number" => phone_number,
            "last_name" => (name.family_name rescue nil),
            "gender" => gender
        }
    }

    return result

  end

  def show

    json = do_query(params[:id])

    patient_id = Order.find_by_accession_number(params[:id]).patient_id rescue nil

    rows = ""

    (0..(json['test_types'].length - 1)).each do |i|

      test_type = json['test_types'][i]

      timestamps = json['results'][test_type].keys rescue []

      keys = json['results'][test_type]['results'].keys rescue []

      if keys.length > 0

        tds = ""

        (1..(keys.length - 1)).each do |j|

          key = keys[j]

          tds += <<EOF
            <tr>
              <td>
                #{key}
              </td>
              <td>
                #{json['results'][test_type]['results'][key] rescue nil}
              </td>
            </tr>
EOF

        end

        rows += <<EOF
          <tr>
            <td rowspan='#{keys.length}' style="vertical-align: top;">
              #{test_type}
            </td>
            <td>
              #{keys[0]}
            </td>
            <td>
              #{json['results'][test_type]['results'][keys[0]] rescue nil}
            </td>
            <td rowspan='#{keys.length}' style="vertical-align: top;">
              #{json['results'][test_type]['remarks']}
            </td>
          </tr>
          #{tds}
EOF

      else

        rows += <<EOF
          <tr>
            <td>
              #{test_type}
            </td>
            <td colspan=3>
              <i>Results not available yet</i>
            </td>
          </tr>
EOF

      end

    end

    page_content = <<EOF

    <html>
      <head>
        <title>LIMS Lab Order View</title>
        <script type="text/javascript" src="/touchscreentoolkit/lib/javascripts/touchScreenToolkit.js" defer="true"></script>
      </head>
      <body>
        <div id="content" style="padding: 0px; background-color: #333;">
          <table width="100%" style="border-collapse: collapse;" cellpadding="0" cellspacing=0>
            <tr>
              <td>
                <div style="height: 70px; border-bottom: 1px solid #ccc; background-color: #334872; color: #eee;
                    font-size: 36px; ">
                  <div style="padding: 11px; padding-top: 23px; float: left; font-size: 18px;">
                    <b>Tracking Number:</b> <i>#{json['_id']}</i>
                  </div>
                  <div style="padding: 11px; float: right;">
                    Lab Results View
                  </div>
                </div>
              </td>
            </tr>
            <tr>
              <td>
                <div style="height: 595px; border: none; overflow: auto; background-color: #fff;">
                  <table style="margin: auto; margin-top: 20px; font-size: 28px; border-collapse: collapse;
                        min-width: 80%;" cellpadding=5>
                    <tr>
                      <td style="text-align: right; font-weight: bold; width: 50%;">
                        Name:
                      </td>
                      <td style="width: 50%;">
                        #{json['patient']['first_name']} #{json['patient']['last_name']} (#{json['patient']['national_patient_id']})
                      </td>
                    </tr>
                    <tr>
                      <td style="text-align: right; font-weight: bold; font-size: 18px; border-top: 1px solid #ccc;
                            background-color: #666; color: #eee;">
                        Sample Type:
                      </td>
                      <td style="font-size: 18px; border-top: 1px solid #ccc; background-color: #666; color: #eee;">
                        #{json['sample_type']}
                      </td>
                    </tr>
                    <tr>
                      <td colspan='2' style="border-top: 1px solid #ccc;">
                        <table width="100%" cellpadding=5 style="border-collapse: collapse;" border=1>
                          <tr style="background-color: #ccc; color: #333;">
                            <th>
                              Test
                            </th>
                            <th>
                              Test Component
                            </th>
                            <th>
                              Test Result
                            </th>
                            <th>
                              Remarks
                            </th>
                          </tr>
                          #{rows}
                        </table>
                      </td>
                    </tr>
                  </table>
                </div>
              </td>
            </tr>
            <tr>
              <td style="background-color: #333;">
                <div style="height: 80px;" class="buttonsDiv">
                  <button class="green" style="float: right;" onmousedown="window.location='/patients/show/#{patient_id}'">
                    <span>Finish</span>
                  </button>
                  <!--button class="blue" style="float: right;"
                        onmousedown="window.location = '/lims?id=000A0Y&location_id=725&collector_first_name=Test&collector_last_name=User&collector_id=P3210'">
                    <span>Print Results</span>
                  </button-->
                  <button class="blue" style="float: right;"
                        onmousedown="window.location = '/lims/fetch_results/#{params[:id]}'">
                    <span>Fetch Results</span>
                  </button>
                </div>
              </td>
            </tr>
          </table>
        </div>
      </body>
    </html>

EOF

    render :text => page_content

  end

  def query

    result = do_query(params[:id])

    render :json => result

  end

  def create

    json = JSON.parse(request.body.read) rescue nil

    redirect_to_show = (json ? false : true)

    json = params if json.nil?

    encounter_type_id = EncounterType.find_by_name("LAB RESULTS").id rescue nil

    patient_id = PatientIdentifier.find_by_identifier(json['patient']['national_patient_id']).patient_id rescue PatientIdentifier.find_by_identifier(json['national_patient_id']).patient_id

    provider_id = User.find_by_username(json['who_order_test']['id_number']).user_id rescue User.current.id

    location_id = Location.find_by_name(json['order_location']).id rescue nil

    creator_id = User.first.user_id rescue nil

    order_type_id = OrderType.find_by_name("Lab").order_type_id rescue nil

    order_concept_id = ConceptName.find_by_name("Laboratory tests ordered").concept_id rescue nil

    sample_type_concept_id = ConceptName.find_by_name("Sample").concept_id rescue nil

    sample_status_concept_id = ConceptName.find_by_name("Status").concept_id rescue nil

    who_updated_first_name_concept_id = ConceptName.find_by_name("Given name").concept_id rescue nil

    who_updated_last_name_concept_id = ConceptName.find_by_name("Family name").concept_id rescue nil

    who_updated_phone_number_concept_id = ConceptName.find_by_name("Phone number").concept_id rescue nil

    who_updated_health_facility_concept_id = ConceptName.find_by_name("Health facility name").concept_id rescue nil

    who_updated_id_number_concept_id = ConceptName.find_by_name("Name of doctor").concept_id rescue nil

    remarks_concept_id = ConceptName.find_by_name("Comments").concept_id rescue nil

    lab_result_concept_id = ConceptName.find_by_name("Lab test result").concept_id rescue nil

    lab_result_value_concept_id = ConceptName.find_by_name("Given lab results").concept_id rescue nil

    art_start_date_concept_id = ConceptName.find_by_name("ART start date").concept_id rescue nil

    date_received_concept_id = ConceptName.find_by_name("Date received").concept_id rescue nil

    date_dispatched_concept_id = ConceptName.find_by_name("Date collected").concept_id rescue nil

    receiving_facility_concept_id = ConceptName.find_by_name("Health facility name").concept_id rescue nil

    sending_facility_concept_id = ConceptName.find_by_name("Source").concept_id rescue nil

    datetime_started_concept_id = ConceptName.find_by_name("Start date").concept_id rescue nil

    date_completed_concept_id = ConceptName.find_by_name("Completed").concept_id rescue nil

    date_drawn_concept_id = ConceptName.find_by_name("Date specimen received").concept_id rescue nil

    priority_concept_id = ConceptName.find_by_name("Indicated urgently").concept_id rescue nil

    reason_for_test_concept_id = ConceptName.find_by_name("Reason for test").concept_id rescue nil

    district_concept_id = ConceptName.find_by_name("District").concept_id rescue nil

    if encounter_type_id and patient_id and provider_id and creator_id and order_type_id and order_concept_id and
        sample_type_concept_id and sample_status_concept_id and who_updated_first_name_concept_id and
        who_updated_last_name_concept_id and who_updated_phone_number_concept_id and remarks_concept_id and
        who_updated_health_facility_concept_id and lab_result_concept_id and lab_result_value_concept_id and
        who_updated_id_number_concept_id and art_start_date_concept_id and date_received_concept_id and
        date_dispatched_concept_id and sending_facility_concept_id and datetime_started_concept_id and
        date_completed_concept_id and date_drawn_concept_id

      encounter = Encounter.create({
                                       :encounter_type => encounter_type_id,
                                       :patient_id => patient_id,
                                       :provider_id => provider_id,
                                       :location_id => location_id,
                                       :encounter_datetime => (json['date_time'].to_date rescue Date.today),
                                       :creator => creator_id,
                                       :date_created => Time.now
                                   })

      order = Order.create({
                               :order_type_id => order_type_id,
                               :concept_id => order_concept_id,
                               :orderer => provider_id,
                               :encounter_id => encounter.encounter_id,
                               :creator => creator_id,
                               :date_created => Time.now,
                               :patient_id => patient_id,
                               :accession_number => json['_id']
                           })

      sample_type = Observation.create({
                                           :person_id => patient_id,
                                           :concept_id => sample_type_concept_id,
                                           :encounter_id => encounter.encounter_id,
                                           :order_id => order.order_id,
                                           :obs_datetime => (json['date_time'].to_date rescue Date.today),
                                           :location_id => location_id,
                                           :accession_number => json['_id'],
                                           :value_text => json['sample_type'],
                                           :creator => creator_id
                                       })

      sample_status = Observation.create({
                                             :person_id => patient_id,
                                             :concept_id => sample_status_concept_id,
                                             :encounter_id => encounter.encounter_id,
                                             :order_id => order.order_id,
                                             :obs_datetime => (json['date_time'].to_date rescue Date.today),
                                             :location_id => location_id,
                                             :accession_number => json['_id'],
                                             :value_text => json['status'],
                                             :creator => creator_id
                                         })

      district = Observation.create({
                                        :person_id => patient_id,
                                        :concept_id => district_concept_id,
                                        :encounter_id => encounter.encounter_id,
                                        :order_id => order.order_id,
                                        :obs_datetime => (json['date_time'].to_date rescue Date.today),
                                        :location_id => location_id,
                                        :accession_number => json['_id'],
                                        :value_text => json['district'],
                                        :creator => creator_id
                                    })

      reason_for_test = Observation.create({
                                               :person_id => patient_id,
                                               :concept_id => reason_for_test_concept_id,
                                               :encounter_id => encounter.encounter_id,
                                               :order_id => order.order_id,
                                               :obs_datetime => (json['date_time'].to_date rescue Date.today),
                                               :location_id => location_id,
                                               :accession_number => json['_id'],
                                               :value_text => json['reason_for_test'],
                                               :creator => creator_id
                                           })

      priority = Observation.create({
                                        :person_id => patient_id,
                                        :concept_id => priority_concept_id,
                                        :encounter_id => encounter.encounter_id,
                                        :order_id => order.order_id,
                                        :obs_datetime => (json['date_time'].to_date rescue Date.today),
                                        :location_id => location_id,
                                        :accession_number => json['_id'],
                                        :value_text => json['priority'],
                                        :creator => creator_id
                                    })

      art_start_date = Observation.create({
                                              :person_id => patient_id,
                                              :concept_id => art_start_date_concept_id,
                                              :encounter_id => encounter.encounter_id,
                                              :order_id => order.order_id,
                                              :obs_datetime => (json['date_time'].to_date rescue Date.today),
                                              :location_id => location_id,
                                              :accession_number => json['_id'],
                                              :value_datetime => (json['art_start_date'].to_date rescue nil),
                                              :creator => creator_id
                                          })

      date_received = Observation.create({
                                             :person_id => patient_id,
                                             :concept_id => date_received_concept_id,
                                             :encounter_id => encounter.encounter_id,
                                             :order_id => order.order_id,
                                             :obs_datetime => (json['date_time'].to_date rescue Date.today),
                                             :location_id => location_id,
                                             :accession_number => json['_id'],
                                             :value_datetime => (json['date_received'].to_date rescue nil),
                                             :creator => creator_id
                                         })

      date_drawn = Observation.create({
                                          :person_id => patient_id,
                                          :concept_id => date_drawn_concept_id,
                                          :encounter_id => encounter.encounter_id,
                                          :order_id => order.order_id,
                                          :obs_datetime => (json['date_time'].to_date rescue Date.today),
                                          :location_id => location_id,
                                          :accession_number => json['_id'],
                                          :value_datetime => (json['date_drawn'].to_date rescue nil),
                                          :creator => creator_id
                                      })

      date_dispatched = Observation.create({
                                               :person_id => patient_id,
                                               :concept_id => date_dispatched_concept_id,
                                               :encounter_id => encounter.encounter_id,
                                               :order_id => order.order_id,
                                               :obs_datetime => (json['date_time'].to_date rescue Date.today),
                                               :location_id => location_id,
                                               :accession_number => json['_id'],
                                               :value_datetime => (json['date_dispatched'].to_date rescue nil),
                                               :creator => creator_id
                                           })

      sending_facility = Observation.create({
                                                :person_id => patient_id,
                                                :concept_id => sending_facility_concept_id,
                                                :encounter_id => encounter.encounter_id,
                                                :order_id => order.order_id,
                                                :obs_datetime => (json['date_time'].to_date rescue Date.today),
                                                :location_id => location_id,
                                                :accession_number => json['_id'],
                                                :value_text => json['sending_facility'],
                                                :creator => creator_id
                                            })

      receiving_facility = Observation.create({
                                                  :person_id => patient_id,
                                                  :concept_id => receiving_facility_concept_id,
                                                  :encounter_id => encounter.encounter_id,
                                                  :order_id => order.order_id,
                                                  :obs_datetime => (json['date_time'].to_date rescue Date.today),
                                                  :location_id => location_id,
                                                  :accession_number => json['_id'],
                                                  :value_text => json['receiving_facility'],
                                                  :creator => creator_id
                                              })

      (0..(json['test_types'].length - 1)).each do |i|

        test_type = json['test_types'][i]

        (0..(json['results'][test_type].keys.length - 1)).each do |j|

          timestamp = json['results'][test_type].keys[j]

          parent = Observation.create({
                                          :person_id => patient_id,
                                          :concept_id => order_concept_id,
                                          :encounter_id => encounter.encounter_id,
                                          :order_id => order.order_id,
                                          :obs_datetime => (json['date_time'].to_date rescue Date.today),
                                          :location_id => location_id,
                                          :accession_number => json['_id'],
                                          :value_text => test_type,
                                          :creator => creator_id
                                      })

          child_wu_fname = Observation.create({
                                                  :person_id => patient_id,
                                                  :concept_id => who_updated_first_name_concept_id,
                                                  :encounter_id => encounter.encounter_id,
                                                  :order_id => order.order_id,
                                                  :obs_datetime => (json['date_time'].to_date rescue Date.today),
                                                  :location_id => location_id,
                                                  :obs_group_id => parent.obs_id,
                                                  :accession_number => json['_id'],
                                                  :value_text => json['results'][test_type][timestamp]['who_updated']['first_name'],
                                                  :creator => creator_id
                                              }) if json['results'][test_type][timestamp]['who_updated'] and
              json['results'][test_type][timestamp]['who_updated']['first_name']

          child_wu_lname = Observation.create({
                                                  :person_id => patient_id,
                                                  :concept_id => who_updated_last_name_concept_id,
                                                  :encounter_id => encounter.encounter_id,
                                                  :order_id => order.order_id,
                                                  :obs_datetime => (json['date_time'].to_date rescue Date.today),
                                                  :location_id => location_id,
                                                  :obs_group_id => parent.obs_id,
                                                  :accession_number => json['_id'],
                                                  :value_text => json['results'][test_type][timestamp]['who_updated']['last_name'],
                                                  :creator => creator_id
                                              }) if json['results'][test_type][timestamp]['who_updated'] and
              json['results'][test_type][timestamp]['who_updated']['last_name']

          child_wu_phone = Observation.create({
                                                  :person_id => patient_id,
                                                  :concept_id => who_updated_phone_number_concept_id,
                                                  :encounter_id => encounter.encounter_id,
                                                  :order_id => order.order_id,
                                                  :obs_datetime => (json['date_time'].to_date rescue Date.today),
                                                  :location_id => location_id,
                                                  :obs_group_id => parent.obs_id,
                                                  :accession_number => json['_id'],
                                                  :value_text => json['results'][test_type][timestamp]['who_updated']['phone_number'],
                                                  :creator => creator_id
                                              }) if json['results'][test_type][timestamp]['who_updated'] and
              json['results'][test_type][timestamp]['who_updated']['phone_number']

          child_wu_id = Observation.create({
                                               :person_id => patient_id,
                                               :concept_id => who_updated_id_number_concept_id,
                                               :encounter_id => encounter.encounter_id,
                                               :order_id => order.order_id,
                                               :obs_datetime => (json['date_time'].to_date rescue Date.today),
                                               :location_id => location_id,
                                               :obs_group_id => parent.obs_id,
                                               :accession_number => json['_id'],
                                               :value_text => json['results'][test_type][timestamp]['who_updated']['ID_number'],
                                               :creator => creator_id
                                           }) if json['results'][test_type][timestamp]['who_updated'] and
              json['results'][test_type][timestamp]['who_updated']['ID_number']

          child_wu_facility = Observation.create({
                                                     :person_id => patient_id,
                                                     :concept_id => who_updated_health_facility_concept_id,
                                                     :encounter_id => encounter.encounter_id,
                                                     :order_id => order.order_id,
                                                     :obs_datetime => (json['date_time'].to_date rescue Date.today),
                                                     :location_id => location_id,
                                                     :obs_group_id => parent.obs_id,
                                                     :accession_number => json['_id'],
                                                     :value_text => json['results'][test_type][timestamp]['who_updated']['facility'],
                                                     :creator => creator_id
                                                 }) if json['results'][test_type][timestamp]['who_updated'] and
              json['results'][test_type][timestamp]['who_updated']['facility']

          child_test_status = Observation.create({
                                                     :person_id => patient_id,
                                                     :concept_id => sample_status_concept_id,
                                                     :encounter_id => encounter.encounter_id,
                                                     :order_id => order.order_id,
                                                     :obs_datetime => (json['date_time'].to_date rescue Date.today),
                                                     :location_id => location_id,
                                                     :obs_group_id => parent.obs_id,
                                                     :accession_number => json['_id'],
                                                     :value_text => json['results'][test_type][timestamp]['test_status'],
                                                     :creator => creator_id
                                                 })

          child_remarks = Observation.create({
                                                 :person_id => patient_id,
                                                 :concept_id => remarks_concept_id,
                                                 :encounter_id => encounter.encounter_id,
                                                 :order_id => order.order_id,
                                                 :obs_datetime => (json['date_time'].to_date rescue Date.today),
                                                 :location_id => location_id,
                                                 :obs_group_id => parent.obs_id,
                                                 :accession_number => json['_id'],
                                                 :value_text => json['results'][test_type][timestamp]['remarks'],
                                                 :creator => creator_id
                                             }) if json['results'][test_type][timestamp]['remarks']

          datetime_started = Observation.create({
                                                    :person_id => patient_id,
                                                    :concept_id => datetime_started_concept_id,
                                                    :encounter_id => encounter.encounter_id,
                                                    :order_id => order.order_id,
                                                    :obs_datetime => (json['date_time'].to_date rescue Date.today),
                                                    :location_id => location_id,
                                                    :obs_group_id => parent.obs_id,
                                                    :accession_number => json['_id'],
                                                    :value_datetime => (json['results'][test_type][timestamp]['datetime_started'].to_date rescue nil),
                                                    :creator => creator_id
                                                }) if json['results'][test_type][timestamp]['datetime_started']

          datetime_completed = Observation.create({
                                                      :person_id => patient_id,
                                                      :concept_id => date_completed_concept_id,
                                                      :encounter_id => encounter.encounter_id,
                                                      :order_id => order.order_id,
                                                      :obs_datetime => (json['date_time'].to_date rescue Date.today),
                                                      :location_id => location_id,
                                                      :obs_group_id => parent.obs_id,
                                                      :accession_number => json['_id'],
                                                      :value_datetime => (json['results'][test_type][timestamp]['datetime_completed'].to_date rescue nil),
                                                      :creator => creator_id
                                                  }) if json['results'][test_type][timestamp]['datetime_completed']

          (0..(json['results'][test_type][timestamp]['results'].keys.length - 1)).each do |k|

            lab_test_measure = json['results'][test_type][timestamp]['results'].keys[k]

            child_result = Observation.create({
                                                  :person_id => patient_id,
                                                  :concept_id => lab_result_concept_id,
                                                  :encounter_id => encounter.encounter_id,
                                                  :order_id => order.order_id,
                                                  :obs_datetime => (json['date_time'].to_date rescue Date.today),
                                                  :location_id => location_id,
                                                  :obs_group_id => parent.obs_id,
                                                  :accession_number => json['_id'],
                                                  :value_text => lab_test_measure,
                                                  :creator => creator_id
                                              })

            child_result = Observation.create({
                                                  :person_id => patient_id,
                                                  :concept_id => lab_result_value_concept_id,
                                                  :encounter_id => encounter.encounter_id,
                                                  :order_id => order.order_id,
                                                  :obs_datetime => (json['date_time'].to_date rescue Date.today),
                                                  :location_id => location_id,
                                                  :obs_group_id => child_result.obs_id,
                                                  :accession_number => json['_id'],
                                                  :value_text => json['results'][test_type][timestamp]['results'][lab_test_measure],
                                                  :creator => creator_id
                                              })

          end

        end rescue nil

      end rescue nil

      if redirect_to_show

        redirect_to "/patients/show/#{patient_id}" and return

      else

        render :text => {'result' => 'SUCCESS', 'error' => false}.to_json

      end

    else

      puts "\n\n#{encounter_type_id} and #{patient_id} and #{provider_id} and #{creator_id} and #{order_type_id} and #{order_concept_id} and " +
               "#{sample_type_concept_id} and #{sample_status_concept_id} and #{who_updated_first_name_concept_id} and " +
               "#{who_updated_last_name_concept_id} and #{who_updated_phone_number_concept_id} and #{remarks_concept_id} and " +
               "#{who_updated_health_facility_concept_id} and #{lab_result_concept_id}\n\n"
      if redirect_to_show

        redirect_to "/patients/show/#{patient_id}" and return

      else

        render :text => {'result' => 'FAILED', 'error' => true}.to_json

      end

    end

  end

  def custom_sample_tests

    settings = YAML.load_file("#{Rails.root}/config/lims.yml")[Rails.env]

    result = RestClient.get("#{settings['protocol']}://#{settings['host']}:#{settings['port']}/sample_tests/#{params[:id].strip.gsub(/\s/, '%20')}")

    json = JSON.parse(result) rescue []

    render :text => "<li>" + json.join("</li><li>") + "</li>"

  end

  def sample_tests

    settings = YAML.load_file("#{Rails.root}/config/lims.yml")[Rails.env]

    result = RestClient.get("#{settings['protocol']}://#{settings['host']}:#{settings['port']}/sample_tests/#{params[:id].strip.gsub(/\s/, '%20')}")

    # json = JSON.parse(result)

    render :text => result

  end

  def update_results(json)

    result = {}

    order = Order.find_by_accession_number(json['_id']) rescue nil

    encounter = Encounter.find(order.encounter_id) rescue nil

    return result if !order or !encounter

    sample_status_concept_id = ConceptName.find_by_name("Status").concept_id rescue nil

    sample_status =
        Observation.find_by_concept_id_and_encounter_id_and_order_id_and_accession_number(sample_status_concept_id,
                                                                                          order.encounter_id,
                                                                                          order.order_id,
                                                                                          order.accession_number
        ).value_text rescue nil

    if !sample_status

      Observation.create({
                             :person_id => order.patient_id,
                             :concept_id => sample_status_concept_id,
                             :encounter_id => order.encounter_id,
                             :order_id => order.order_id,
                             :obs_datetime => (json['date_time'].to_date rescue Date.today),
                             :location_id => nil,
                             :accession_number => json['_id'],
                             :value_text => json['status'],
                             :creator => order.creator_id
                         })

    elsif json['status'].strip.downcase != sample_status.strip.downcase

      Observation.find_by_concept_id_and_encounter_id_and_order_id_and_accession_number(sample_status_concept_id,
                                                                                        order.encounter_id,
                                                                                        order.order_id,
                                                                                        order.accession_number
      ).update_attributes({:value_text => json['status']})

    end

    patient_id = PatientIdentifier.find_by_identifier(json['patient']['national_patient_id']).patient_id rescue nil

    provider_id = User.find_by_username(json['who_order_test']['id_number']).user_id rescue nil

    location_id = Location.find_by_name(json['order_location']).id rescue nil

    creator_id = User.first.user_id rescue nil

    order_type_id = OrderType.find_by_name("Lab").order_type_id rescue nil

    order_concept_id = ConceptName.find_by_name("Laboratory tests ordered").concept_id rescue nil

    sample_type_concept_id = ConceptName.find_by_name("Sample").concept_id rescue nil

    sample_status_concept_id = ConceptName.find_by_name("Status").concept_id rescue nil

    who_updated_first_name_concept_id = ConceptName.find_by_name("Given name").concept_id rescue nil

    who_updated_last_name_concept_id = ConceptName.find_by_name("Family name").concept_id rescue nil

    who_updated_phone_number_concept_id = ConceptName.find_by_name("Phone number").concept_id rescue nil

    who_updated_health_facility_concept_id = ConceptName.find_by_name("Health facility name").concept_id rescue nil

    who_updated_id_number_concept_id = ConceptName.find_by_name("Name of doctor").concept_id rescue nil

    remarks_concept_id = ConceptName.find_by_name("Comments").concept_id rescue nil

    lab_result_concept_id = ConceptName.find_by_name("Lab test result").concept_id rescue nil

    lab_result_value_concept_id = ConceptName.find_by_name("Given lab results").concept_id rescue nil

    art_start_date_concept_id = ConceptName.find_by_name("ART start date").concept_id rescue nil

    date_received_concept_id = ConceptName.find_by_name("Date received").concept_id rescue nil

    date_dispatched_concept_id = ConceptName.find_by_name("Date collected").concept_id rescue nil

    receiving_facility_concept_id = ConceptName.find_by_name("Health facility name").concept_id rescue nil

    sending_facility_concept_id = ConceptName.find_by_name("Source").concept_id rescue nil

    datetime_started_concept_id = ConceptName.find_by_name("Start date").concept_id rescue nil

    date_completed_concept_id = ConceptName.find_by_name("Completed").concept_id rescue nil

    date_drawn_concept_id = ConceptName.find_by_name("Date specimen received").concept_id rescue nil

    priority_concept_id = ConceptName.find_by_name("Indicated urgently").concept_id rescue nil

    reason_for_test_concept_id = ConceptName.find_by_name("Reason for test").concept_id rescue nil

    district_concept_id = ConceptName.find_by_name("District").concept_id rescue nil

    json['test_types'].each do |test_type|

      next if json['results'][test_type].keys.length <= 0

      child = json['results'][test_type][json['results'][test_type].keys[0]]

      order_concept_id = ConceptName.find_by_name("Laboratory tests ordered").concept_id rescue nil

      obs = Observation.find_by_concept_id_and_encounter_id_and_order_id_and_accession_number(order_concept_id,
                                                                                              order.encounter_id,
                                                                                              order.order_id,
                                                                                              order.accession_number
      ) rescue nil

      if !obs

        (0..(json['results'][test_type].keys.length - 1)).each do |j|

          timestamp = json['results'][test_type].keys[j]

          parent = Observation.create({
                                          :person_id => patient_id,
                                          :concept_id => order_concept_id,
                                          :encounter_id => encounter.encounter_id,
                                          :order_id => order.order_id,
                                          :obs_datetime => (json['date_time'].to_date rescue Date.today),
                                          :location_id => location_id,
                                          :accession_number => json['_id'],
                                          :value_text => test_type,
                                          :creator => creator_id
                                      })

          child_wu_fname = Observation.create({
                                                  :person_id => patient_id,
                                                  :concept_id => who_updated_first_name_concept_id,
                                                  :encounter_id => encounter.encounter_id,
                                                  :order_id => order.order_id,
                                                  :obs_datetime => (json['date_time'].to_date rescue Date.today),
                                                  :location_id => location_id,
                                                  :obs_group_id => parent.obs_id,
                                                  :accession_number => json['_id'],
                                                  :value_text => json['results'][test_type][timestamp]['who_updated']['first_name'],
                                                  :creator => creator_id
                                              }) if json['results'][test_type][timestamp]['who_updated'] and
              json['results'][test_type][timestamp]['who_updated']['first_name']

          child_wu_lname = Observation.create({
                                                  :person_id => patient_id,
                                                  :concept_id => who_updated_last_name_concept_id,
                                                  :encounter_id => encounter.encounter_id,
                                                  :order_id => order.order_id,
                                                  :obs_datetime => (json['date_time'].to_date rescue Date.today),
                                                  :location_id => location_id,
                                                  :obs_group_id => parent.obs_id,
                                                  :accession_number => json['_id'],
                                                  :value_text => json['results'][test_type][timestamp]['who_updated']['last_name'],
                                                  :creator => creator_id
                                              }) if json['results'][test_type][timestamp]['who_updated'] and
              json['results'][test_type][timestamp]['who_updated']['last_name']

          child_wu_phone = Observation.create({
                                                  :person_id => patient_id,
                                                  :concept_id => who_updated_phone_number_concept_id,
                                                  :encounter_id => encounter.encounter_id,
                                                  :order_id => order.order_id,
                                                  :obs_datetime => (json['date_time'].to_date rescue Date.today),
                                                  :location_id => location_id,
                                                  :obs_group_id => parent.obs_id,
                                                  :accession_number => json['_id'],
                                                  :value_text => json['results'][test_type][timestamp]['who_updated']['phone_number'],
                                                  :creator => creator_id
                                              }) if json['results'][test_type][timestamp]['who_updated'] and
              json['results'][test_type][timestamp]['who_updated']['phone_number']

          child_wu_id = Observation.create({
                                               :person_id => patient_id,
                                               :concept_id => who_updated_id_number_concept_id,
                                               :encounter_id => encounter.encounter_id,
                                               :order_id => order.order_id,
                                               :obs_datetime => (json['date_time'].to_date rescue Date.today),
                                               :location_id => location_id,
                                               :obs_group_id => parent.obs_id,
                                               :accession_number => json['_id'],
                                               :value_text => json['results'][test_type][timestamp]['who_updated']['ID_number'],
                                               :creator => creator_id
                                           }) if json['results'][test_type][timestamp]['who_updated'] and
              json['results'][test_type][timestamp]['who_updated']['ID_number']

          child_wu_facility = Observation.create({
                                                     :person_id => patient_id,
                                                     :concept_id => who_updated_health_facility_concept_id,
                                                     :encounter_id => encounter.encounter_id,
                                                     :order_id => order.order_id,
                                                     :obs_datetime => (json['date_time'].to_date rescue Date.today),
                                                     :location_id => location_id,
                                                     :obs_group_id => parent.obs_id,
                                                     :accession_number => json['_id'],
                                                     :value_text => json['results'][test_type][timestamp]['who_updated']['facility'],
                                                     :creator => creator_id
                                                 }) if json['results'][test_type][timestamp]['who_updated'] and
              json['results'][test_type][timestamp]['who_updated']['facility']

          child_test_status = Observation.create({
                                                     :person_id => patient_id,
                                                     :concept_id => sample_status_concept_id,
                                                     :encounter_id => encounter.encounter_id,
                                                     :order_id => order.order_id,
                                                     :obs_datetime => (json['date_time'].to_date rescue Date.today),
                                                     :location_id => location_id,
                                                     :obs_group_id => parent.obs_id,
                                                     :accession_number => json['_id'],
                                                     :value_text => json['results'][test_type][timestamp]['test_status'],
                                                     :creator => creator_id
                                                 })

          child_remarks = Observation.create({
                                                 :person_id => patient_id,
                                                 :concept_id => remarks_concept_id,
                                                 :encounter_id => encounter.encounter_id,
                                                 :order_id => order.order_id,
                                                 :obs_datetime => (json['date_time'].to_date rescue Date.today),
                                                 :location_id => location_id,
                                                 :obs_group_id => parent.obs_id,
                                                 :accession_number => json['_id'],
                                                 :value_text => json['results'][test_type][timestamp]['remarks'],
                                                 :creator => creator_id
                                             }) if json['results'][test_type][timestamp]['remarks']

          datetime_started = Observation.create({
                                                    :person_id => patient_id,
                                                    :concept_id => datetime_started_concept_id,
                                                    :encounter_id => encounter.encounter_id,
                                                    :order_id => order.order_id,
                                                    :obs_datetime => (json['date_time'].to_date rescue Date.today),
                                                    :location_id => location_id,
                                                    :obs_group_id => parent.obs_id,
                                                    :accession_number => json['_id'],
                                                    :value_datetime => (json['results'][test_type][timestamp]['datetime_started'].to_date rescue nil),
                                                    :creator => creator_id
                                                }) if json['results'][test_type][timestamp]['datetime_started']

          datetime_completed = Observation.create({
                                                      :person_id => patient_id,
                                                      :concept_id => date_completed_concept_id,
                                                      :encounter_id => encounter.encounter_id,
                                                      :order_id => order.order_id,
                                                      :obs_datetime => (json['date_time'].to_date rescue Date.today),
                                                      :location_id => location_id,
                                                      :obs_group_id => parent.obs_id,
                                                      :accession_number => json['_id'],
                                                      :value_datetime => (json['results'][test_type][timestamp]['datetime_completed'].to_date rescue nil),
                                                      :creator => creator_id
                                                  }) if json['results'][test_type][timestamp]['datetime_completed']

          (0..(json['results'][test_type][timestamp]['results'].keys.length - 1)).each do |k|

            lab_test_measure = json['results'][test_type][timestamp]['results'].keys[k]

            child_result = Observation.create({
                                                  :person_id => patient_id,
                                                  :concept_id => lab_result_concept_id,
                                                  :encounter_id => encounter.encounter_id,
                                                  :order_id => order.order_id,
                                                  :obs_datetime => (json['date_time'].to_date rescue Date.today),
                                                  :location_id => location_id,
                                                  :obs_group_id => parent.obs_id,
                                                  :accession_number => json['_id'],
                                                  :value_text => lab_test_measure,
                                                  :creator => creator_id
                                              })

            child_result = Observation.create({
                                                  :person_id => patient_id,
                                                  :concept_id => lab_result_value_concept_id,
                                                  :encounter_id => encounter.encounter_id,
                                                  :order_id => order.order_id,
                                                  :obs_datetime => (json['date_time'].to_date rescue Date.today),
                                                  :location_id => location_id,
                                                  :obs_group_id => child_result.obs_id,
                                                  :accession_number => json['_id'],
                                                  :value_text => json['results'][test_type][timestamp]['results'][lab_test_measure],
                                                  :creator => creator_id
                                              })

          end

        end

      else

        test_status = Observation.find_by_concept_id_and_encounter_id_and_order_id_and_obs_group_id_and_accession_number(sample_status_concept_id,
                                                                                                                         order.encounter_id,
                                                                                                                         order.order_id,
                                                                                                                         obs.obs_id,
                                                                                                                         order.accession_number
        ).value_text rescue nil

        if !test_status

          (0..(json['results'][test_type].keys.length - 1)).each do |j|

            timestamp = json['results'][test_type].keys[j]

            parent = Observation.create({
                                            :person_id => patient_id,
                                            :concept_id => order_concept_id,
                                            :encounter_id => encounter.encounter_id,
                                            :order_id => order.order_id,
                                            :obs_datetime => (json['date_time'].to_date rescue Date.today),
                                            :location_id => location_id,
                                            :accession_number => json['_id'],
                                            :value_text => test_type,
                                            :creator => creator_id
                                        })

            child_wu_fname = Observation.create({
                                                    :person_id => patient_id,
                                                    :concept_id => who_updated_first_name_concept_id,
                                                    :encounter_id => encounter.encounter_id,
                                                    :order_id => order.order_id,
                                                    :obs_datetime => (json['date_time'].to_date rescue Date.today),
                                                    :location_id => location_id,
                                                    :obs_group_id => parent.obs_id,
                                                    :accession_number => json['_id'],
                                                    :value_text => json['results'][test_type][timestamp]['who_updated']['first_name'],
                                                    :creator => creator_id
                                                }) if json['results'][test_type][timestamp]['who_updated'] and
                json['results'][test_type][timestamp]['who_updated']['first_name']

            child_wu_lname = Observation.create({
                                                    :person_id => patient_id,
                                                    :concept_id => who_updated_last_name_concept_id,
                                                    :encounter_id => encounter.encounter_id,
                                                    :order_id => order.order_id,
                                                    :obs_datetime => (json['date_time'].to_date rescue Date.today),
                                                    :location_id => location_id,
                                                    :obs_group_id => parent.obs_id,
                                                    :accession_number => json['_id'],
                                                    :value_text => json['results'][test_type][timestamp]['who_updated']['last_name'],
                                                    :creator => creator_id
                                                }) if json['results'][test_type][timestamp]['who_updated'] and
                json['results'][test_type][timestamp]['who_updated']['last_name']

            child_wu_phone = Observation.create({
                                                    :person_id => patient_id,
                                                    :concept_id => who_updated_phone_number_concept_id,
                                                    :encounter_id => encounter.encounter_id,
                                                    :order_id => order.order_id,
                                                    :obs_datetime => (json['date_time'].to_date rescue Date.today),
                                                    :location_id => location_id,
                                                    :obs_group_id => parent.obs_id,
                                                    :accession_number => json['_id'],
                                                    :value_text => json['results'][test_type][timestamp]['who_updated']['phone_number'],
                                                    :creator => creator_id
                                                }) if json['results'][test_type][timestamp]['who_updated'] and
                json['results'][test_type][timestamp]['who_updated']['phone_number']

            child_wu_id = Observation.create({
                                                 :person_id => patient_id,
                                                 :concept_id => who_updated_id_number_concept_id,
                                                 :encounter_id => encounter.encounter_id,
                                                 :order_id => order.order_id,
                                                 :obs_datetime => (json['date_time'].to_date rescue Date.today),
                                                 :location_id => location_id,
                                                 :obs_group_id => parent.obs_id,
                                                 :accession_number => json['_id'],
                                                 :value_text => json['results'][test_type][timestamp]['who_updated']['ID_number'],
                                                 :creator => creator_id
                                             }) if json['results'][test_type][timestamp]['who_updated'] and
                json['results'][test_type][timestamp]['who_updated']['ID_number']

            child_wu_facility = Observation.create({
                                                       :person_id => patient_id,
                                                       :concept_id => who_updated_health_facility_concept_id,
                                                       :encounter_id => encounter.encounter_id,
                                                       :order_id => order.order_id,
                                                       :obs_datetime => (json['date_time'].to_date rescue Date.today),
                                                       :location_id => location_id,
                                                       :obs_group_id => parent.obs_id,
                                                       :accession_number => json['_id'],
                                                       :value_text => json['results'][test_type][timestamp]['who_updated']['facility'],
                                                       :creator => creator_id
                                                   }) if json['results'][test_type][timestamp]['who_updated'] and
                json['results'][test_type][timestamp]['who_updated']['facility']

            child_test_status = Observation.create({
                                                       :person_id => patient_id,
                                                       :concept_id => sample_status_concept_id,
                                                       :encounter_id => encounter.encounter_id,
                                                       :order_id => order.order_id,
                                                       :obs_datetime => (json['date_time'].to_date rescue Date.today),
                                                       :location_id => location_id,
                                                       :obs_group_id => parent.obs_id,
                                                       :accession_number => json['_id'],
                                                       :value_text => json['results'][test_type][timestamp]['test_status'],
                                                       :creator => creator_id
                                                   })

            child_remarks = Observation.create({
                                                   :person_id => patient_id,
                                                   :concept_id => remarks_concept_id,
                                                   :encounter_id => encounter.encounter_id,
                                                   :order_id => order.order_id,
                                                   :obs_datetime => (json['date_time'].to_date rescue Date.today),
                                                   :location_id => location_id,
                                                   :obs_group_id => parent.obs_id,
                                                   :accession_number => json['_id'],
                                                   :value_text => json['results'][test_type][timestamp]['remarks'],
                                                   :creator => creator_id
                                               }) if json['results'][test_type][timestamp]['remarks']

            datetime_started = Observation.create({
                                                      :person_id => patient_id,
                                                      :concept_id => datetime_started_concept_id,
                                                      :encounter_id => encounter.encounter_id,
                                                      :order_id => order.order_id,
                                                      :obs_datetime => (json['date_time'].to_date rescue Date.today),
                                                      :location_id => location_id,
                                                      :obs_group_id => parent.obs_id,
                                                      :accession_number => json['_id'],
                                                      :value_datetime => (json['results'][test_type][timestamp]['datetime_started'].to_date rescue nil),
                                                      :creator => creator_id
                                                  }) if json['results'][test_type][timestamp]['datetime_started']

            datetime_completed = Observation.create({
                                                        :person_id => patient_id,
                                                        :concept_id => date_completed_concept_id,
                                                        :encounter_id => encounter.encounter_id,
                                                        :order_id => order.order_id,
                                                        :obs_datetime => (json['date_time'].to_date rescue Date.today),
                                                        :location_id => location_id,
                                                        :obs_group_id => parent.obs_id,
                                                        :accession_number => json['_id'],
                                                        :value_datetime => (json['results'][test_type][timestamp]['datetime_completed'].to_date rescue nil),
                                                        :creator => creator_id
                                                    }) if json['results'][test_type][timestamp]['datetime_completed']

            (0..(json['results'][test_type][timestamp]['results'].keys.length - 1)).each do |k|

              lab_test_measure = json['results'][test_type][timestamp]['results'].keys[k]

              child_result = Observation.create({
                                                    :person_id => patient_id,
                                                    :concept_id => lab_result_concept_id,
                                                    :encounter_id => encounter.encounter_id,
                                                    :order_id => order.order_id,
                                                    :obs_datetime => (json['date_time'].to_date rescue Date.today),
                                                    :location_id => location_id,
                                                    :obs_group_id => parent.obs_id,
                                                    :accession_number => json['_id'],
                                                    :value_text => lab_test_measure,
                                                    :creator => creator_id
                                                })

              child_result = Observation.create({
                                                    :person_id => patient_id,
                                                    :concept_id => lab_result_value_concept_id,
                                                    :encounter_id => encounter.encounter_id,
                                                    :order_id => order.order_id,
                                                    :obs_datetime => (json['date_time'].to_date rescue Date.today),
                                                    :location_id => location_id,
                                                    :obs_group_id => child_result.obs_id,
                                                    :accession_number => json['_id'],
                                                    :value_text => json['results'][test_type][timestamp]['results'][lab_test_measure],
                                                    :creator => creator_id
                                                })

            end

          end

        else

          (0..(json['results'][test_type].keys.length - 1)).each do |j|

            timestamp = json['results'][test_type].keys[j]

            parent = obs

            child_wu_fname = Observation.create({
                                                    :person_id => patient_id,
                                                    :concept_id => who_updated_first_name_concept_id,
                                                    :encounter_id => encounter.encounter_id,
                                                    :order_id => order.order_id,
                                                    :obs_datetime => (json['date_time'].to_date rescue Date.today),
                                                    :location_id => location_id,
                                                    :obs_group_id => parent.obs_id,
                                                    :accession_number => json['_id'],
                                                    :value_text => json['results'][test_type][timestamp]['who_updated']['first_name'],
                                                    :creator => creator_id
                                                }) if json['results'][test_type][timestamp]['who_updated'] and
                json['results'][test_type][timestamp]['who_updated']['first_name']

            child_wu_lname = Observation.create({
                                                    :person_id => patient_id,
                                                    :concept_id => who_updated_last_name_concept_id,
                                                    :encounter_id => encounter.encounter_id,
                                                    :order_id => order.order_id,
                                                    :obs_datetime => (json['date_time'].to_date rescue Date.today),
                                                    :location_id => location_id,
                                                    :obs_group_id => parent.obs_id,
                                                    :accession_number => json['_id'],
                                                    :value_text => json['results'][test_type][timestamp]['who_updated']['last_name'],
                                                    :creator => creator_id
                                                }) if json['results'][test_type][timestamp]['who_updated'] and
                json['results'][test_type][timestamp]['who_updated']['last_name']

            child_wu_phone = Observation.create({
                                                    :person_id => patient_id,
                                                    :concept_id => who_updated_phone_number_concept_id,
                                                    :encounter_id => encounter.encounter_id,
                                                    :order_id => order.order_id,
                                                    :obs_datetime => (json['date_time'].to_date rescue Date.today),
                                                    :location_id => location_id,
                                                    :obs_group_id => parent.obs_id,
                                                    :accession_number => json['_id'],
                                                    :value_text => json['results'][test_type][timestamp]['who_updated']['phone_number'],
                                                    :creator => creator_id
                                                }) if json['results'][test_type][timestamp]['who_updated'] and
                json['results'][test_type][timestamp]['who_updated']['phone_number']

            child_wu_id = Observation.create({
                                                 :person_id => patient_id,
                                                 :concept_id => who_updated_id_number_concept_id,
                                                 :encounter_id => encounter.encounter_id,
                                                 :order_id => order.order_id,
                                                 :obs_datetime => (json['date_time'].to_date rescue Date.today),
                                                 :location_id => location_id,
                                                 :obs_group_id => parent.obs_id,
                                                 :accession_number => json['_id'],
                                                 :value_text => json['results'][test_type][timestamp]['who_updated']['ID_number'],
                                                 :creator => creator_id
                                             }) if json['results'][test_type][timestamp]['who_updated'] and
                json['results'][test_type][timestamp]['who_updated']['ID_number']

            child_wu_facility = Observation.create({
                                                       :person_id => patient_id,
                                                       :concept_id => who_updated_health_facility_concept_id,
                                                       :encounter_id => encounter.encounter_id,
                                                       :order_id => order.order_id,
                                                       :obs_datetime => (json['date_time'].to_date rescue Date.today),
                                                       :location_id => location_id,
                                                       :obs_group_id => parent.obs_id,
                                                       :accession_number => json['_id'],
                                                       :value_text => json['results'][test_type][timestamp]['who_updated']['facility'],
                                                       :creator => creator_id
                                                   }) if json['results'][test_type][timestamp]['who_updated'] and
                json['results'][test_type][timestamp]['who_updated']['facility']

            child_test_status = Observation.create({
                                                       :person_id => patient_id,
                                                       :concept_id => sample_status_concept_id,
                                                       :encounter_id => encounter.encounter_id,
                                                       :order_id => order.order_id,
                                                       :obs_datetime => (json['date_time'].to_date rescue Date.today),
                                                       :location_id => location_id,
                                                       :obs_group_id => parent.obs_id,
                                                       :accession_number => json['_id'],
                                                       :value_text => json['results'][test_type][timestamp]['test_status'],
                                                       :creator => creator_id
                                                   })

            child_remarks = Observation.create({
                                                   :person_id => patient_id,
                                                   :concept_id => remarks_concept_id,
                                                   :encounter_id => encounter.encounter_id,
                                                   :order_id => order.order_id,
                                                   :obs_datetime => (json['date_time'].to_date rescue Date.today),
                                                   :location_id => location_id,
                                                   :obs_group_id => parent.obs_id,
                                                   :accession_number => json['_id'],
                                                   :value_text => json['results'][test_type][timestamp]['remarks'],
                                                   :creator => creator_id
                                               }) if json['results'][test_type][timestamp]['remarks']

            datetime_started = Observation.create({
                                                      :person_id => patient_id,
                                                      :concept_id => datetime_started_concept_id,
                                                      :encounter_id => encounter.encounter_id,
                                                      :order_id => order.order_id,
                                                      :obs_datetime => (json['date_time'].to_date rescue Date.today),
                                                      :location_id => location_id,
                                                      :obs_group_id => parent.obs_id,
                                                      :accession_number => json['_id'],
                                                      :value_datetime => (json['results'][test_type][timestamp]['datetime_started'].to_date rescue nil),
                                                      :creator => creator_id
                                                  }) if json['results'][test_type][timestamp]['datetime_started']

            datetime_completed = Observation.create({
                                                        :person_id => patient_id,
                                                        :concept_id => date_completed_concept_id,
                                                        :encounter_id => encounter.encounter_id,
                                                        :order_id => order.order_id,
                                                        :obs_datetime => (json['date_time'].to_date rescue Date.today),
                                                        :location_id => location_id,
                                                        :obs_group_id => parent.obs_id,
                                                        :accession_number => json['_id'],
                                                        :value_datetime => (json['results'][test_type][timestamp]['datetime_completed'].to_date rescue nil),
                                                        :creator => creator_id
                                                    }) if json['results'][test_type][timestamp]['datetime_completed']

            (0..(json['results'][test_type][timestamp]['results'].keys.length - 1)).each do |k|

              lab_test_measure = json['results'][test_type][timestamp]['results'].keys[k]

              child_result = Observation.create({
                                                    :person_id => patient_id,
                                                    :concept_id => lab_result_concept_id,
                                                    :encounter_id => encounter.encounter_id,
                                                    :order_id => order.order_id,
                                                    :obs_datetime => (json['date_time'].to_date rescue Date.today),
                                                    :location_id => location_id,
                                                    :obs_group_id => parent.obs_id,
                                                    :accession_number => json['_id'],
                                                    :value_text => lab_test_measure,
                                                    :creator => creator_id
                                                })

              child_result = Observation.create({
                                                    :person_id => patient_id,
                                                    :concept_id => lab_result_value_concept_id,
                                                    :encounter_id => encounter.encounter_id,
                                                    :order_id => order.order_id,
                                                    :obs_datetime => (json['date_time'].to_date rescue Date.today),
                                                    :location_id => location_id,
                                                    :obs_group_id => child_result.obs_id,
                                                    :accession_number => json['_id'],
                                                    :value_text => json['results'][test_type][timestamp]['results'][lab_test_measure],
                                                    :creator => creator_id
                                                })

            end

          end

        end

      end

    end

  end

  def fetch_results

    settings = YAML.load_file("#{Rails.root}/config/lims.yml")[Rails.env]

    result = RestClient.get("#{settings['protocol']}://#{settings['host']}:#{settings['port']}#{settings['query_path']}#{params[:id].strip.gsub(/\s/, '%20')}")

    json = JSON.parse(result) rescue []

    outcome = update_results(json)

    redirect_to "/lims/show/#{json['_id']}"

  end

  def generic_results
    @results = []
    @patient = Patient.find(params[:id])
    patient_ids = id_identifiers(@patient)
    @patient_bean = PatientService.get_patient(@patient.person)
    # (Lab.results(@patient, patient_ids) || []).map do | short_name , test_name , range , value , test_date |
    #  @results << [short_name.gsub('_',' '),"/lab/view?test=#{short_name}&patient_id=#{@patient.id}"]
    # end

    Observation.all(:conditions => ["person_id = ? AND concept_id = ?", params[:id],
                                    (ConceptName.find_by_name("Laboratory tests ordered").concept_id rescue nil)]).each do |obs|

      @results << [obs.value_text, "/lab/view?test=#{obs.value_text.gsub(/\s/, "+")}&patient_id=#{@patient.id}"]

    end

    @enter_lab_results = GlobalProperty.find_by_property('enter.lab.results').property_value == 'true' rescue false
    render :layout => 'menu', :template => '/lab/results'
  end

  def generic_view
    @patient = Patient.find(params[:patient_id])
    @patient_bean = PatientService.get_patient(@patient.person)
    @test = params[:test]
    patient_ids = id_identifiers(@patient)
    # @results = Lab.results_by_type(@patient, @test, patient_ids)

    @results = {}

    Observation.all(:conditions => ["person_id = ? AND concept_id = ? AND value_text = ?", params[:patient_id],
                                    (ConceptName.find_by_name("Laboratory tests ordered").concept_id rescue nil),
                                    @test
    ]).each do |obs|

      Observation.all(:conditions => ["person_id = ? AND concept_id = ? AND obs_group_id = ?", params[:patient_id],
                                      (ConceptName.find_by_name("Lab test result").concept_id rescue nil), obs.obs_id]).each do |result|

        key = "#{obs.obs_datetime.to_date.strftime("%Y-%m-%d") rescue "????-??-??"}::#{result.value_text rescue nil}"

        test_result = Observation.find_by_person_id_and_concept_id_and_obs_group_id(params[:patient_id],
                                                                                    (ConceptName.find_by_name("Given lab results").concept_id rescue nil),
                                                                                    result.obs_id).value_text rescue nil

        @results[key] = {
            "TestValue" => test_result
        }

      end

    end

    @all = {}
    (@results || []).map do |key, values|
      date = key.split("::")[0].to_date rescue "1900-01-01".to_date
      name = key.split("::")[1].strip
      value = values["TestValue"]
      next if date == "1900-01-01".to_date and value.blank?
      next if ((Date.today - 2.year) > date)
      @all[name] = [] if @all[name].blank?
      @all[name] << [date, value]
      @all[name] = @all[name].sort
    end

    @table_th = build_table(@results) unless @results.blank?
    render :layout => 'menu', :template => '/lab/view'
  end

  def generic_graph
    @results = []
    params[:results].split(';').map do |result|

      date = result.split(',')[0].to_date rescue '1900-01-01'
      modifier = result.split(',')[1].split(" ")[0].sub('more_than', '>').sub('less_than', '<')
      value = result.split(',')[1].sub('more_than', '').sub('less_than', '').sub('=', '') rescue nil
      next if value.blank?
      value = value.to_f

      @results << [date, value, modifier]
    end

    @patient = Patient.find(params[:patient_id])
    @patient_bean = PatientService.get_patient(@patient.person)
    @type = params[:type]
    @test = params[:test]
    render :layout => 'menu', :template => '/lab/graph'
  end

  def build_table(results)
    available_dates = Array.new()
    available_test_types = Array.new()
    html_tag = Array.new()
    html_tag_to_display = nil

    results.each do |key, values|
      date = key.split("::")[0].to_date rescue 'Unknown'
      available_dates << date
      available_test_types << key.split("::")[1]
    end

    available_dates = available_dates.compact.uniq.sort.reverse rescue []
    available_test_types = available_test_types.compact.uniq rescue []
    return if available_dates.blank?


    #from the available test dates we create
    #the top row which holds all the lab run test date  - quick hack :)
    @table_tr = "<tr><th>&nbsp;</th>"; count = 0
    available_dates.map do |date|
      @table_tr += "<th id='#{count+=1}'>#{date}</th>"
    end; @table_tr += "</tr>"

    #same here - we create all the row which will hold the actual
    #lab results .. quick hack :)
    @table_tr_data = ''
    available_test_types.map do |type|
      @table_tr_data += "<tr><td><a href = '#' onmousedown=\"graph('#{type}');\">#{type.gsub('_', ' ')}</a></td>"
      count = 0
      available_dates.map do |date|
        @table_tr_data += "<td id = '#{type}_#{count+=1}' id='#{date}::#{type}'></td>"
      end
      @table_tr_data += "</tr>"
    end

    results.each do |key, values|
      value = values['Range'].to_s + ' ' + values['TestValue'].to_s
      @table_tr_data = @table_tr_data.sub(" id='#{key}'>", " class=#{}>#{value}")
    end


    return (@table_tr + @table_tr_data)
  end

  def id_identifiers(patient)
    identifier_type = ["Legacy Pediatric id", "National id", "Legacy National id", "Old Identification Number"]
    identifier_types = PatientIdentifierType.find(:all,
                                                  :conditions => ["name IN (?)", identifier_type]
    ).collect { |type| type.id }

    identifiers = []
    PatientIdentifier.find(:all,
                           :conditions => ["patient_id=? AND identifier_type IN (?)",
                                           patient.id, identifier_types]).each { |i| identifiers << i.identifier }

    patient_obj = PatientService.get_patient(patient.person)

    ActiveRecord::Base.connection.select_all("SELECT * FROM patient_identifier
      WHERE identifier_type IN(#{identifier_types.join(',')})
      AND voided = 1 AND patient_id = #{patient.id}
      AND void_reason LIKE '%Given new national ID: #{patient_obj.national_id}%'").collect { |r| identifiers << r['identifier'] }
    return identifiers
  end

  def generic_series
    @values = params[:results]
    @patient = Patient.find(params[:patient_id])
    @patient_bean = PatientService.get_patient(@patient.person)
    @test = params[:type]
    render :layout => 'menu', :template => '/charts/series'
  end

end

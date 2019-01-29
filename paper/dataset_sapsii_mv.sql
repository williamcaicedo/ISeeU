--DROP MATERIALIZED VIEW IF EXISTS mimiciii.dataset;
CREATE MATERIALIZED VIEW mimiciii.datasetSAPSII AS
  WITH cohort AS
  (
    --first vital signs stuff
    SELECT
      i.subject_id,
      i.hadm_id,
      EXTRACT(EPOCH FROM i.intime - p.dob) / 60.0 / 60.0 / 24.0 / 365.242 AS AGE,
      CASE
      WHEN ad.ADMISSION_TYPE = 'ELECTIVE' THEN 1
      ELSE 0 END                                                          AS elective,
      CASE
      WHEN lower(ser.CURR_SERVICE) like '%surg%' then 1
      ELSE 0 END                                                          AS surgical,
      CASE
      WHEN icd9_code BETWEEN '042' AND '0449'
        THEN 1
		  ELSE 0 END                                                          AS AIDS      /* HIV and AIDS */,
      CASE
      WHEN icd9_code BETWEEN '1960' AND '1991' THEN 1
      WHEN icd9_code BETWEEN '20970' AND '20975' THEN 1
      WHEN icd9_code = '20979' THEN 1
      WHEN icd9_code = '78951' THEN 1
      ELSE 0 END                                                         AS METASTATIC_CANCER,
      CASE
      WHEN icd9_code BETWEEN '20000' AND '20238' THEN 1 -- lymphoma
      WHEN icd9_code BETWEEN '20240' AND '20248' THEN 1 -- leukemia
      WHEN icd9_code BETWEEN '20250' AND '20302' THEN 1 -- lymphoma
      WHEN icd9_code BETWEEN '20310' AND '20312' THEN 1 -- leukemia
      WHEN icd9_code BETWEEN '20302' AND '20382' THEN 1 -- lymphoma
      WHEN icd9_code BETWEEN '20400' AND '20522' THEN 1 -- chronic leukemia
      WHEN icd9_code BETWEEN '20580' AND '20702' THEN 1 -- other myeloid leukemia
      WHEN icd9_code BETWEEN '20720' AND '20892' THEN 1 -- other myeloid leukemia
      WHEN icd9_code = '2386 ' THEN 1 -- lymphoma
      WHEN icd9_code = '2733 ' THEN 1 -- lymphoma
      ELSE 0 END                                                         AS LYMPHOMA,
      RANK()
      OVER (
        PARTITION BY i.subject_id
        ORDER BY i.intime )                                               AS icustay_id_order,
      CASE
      WHEN ad.deathtime BETWEEN i.intime AND i.outtime
        THEN 1
      ELSE 0 END                                                          AS mort_icu
      --, d.label as variable_name
      ,
      CASE
      WHEN itemid IN (723, 223900) AND valuenum >= 1 AND valuenum <= 5 --OK
        THEN 'GCSVerbal'
      WHEN itemid IN (454, 223901) AND valuenum >= 1 AND valuenum <= 6 --OK
        THEN 'GCSMotor'
      WHEN itemid IN (184, 220739) AND valuenum >= 1 AND valuenum <= 6 --OK
        THEN 'GCSEyes'
      WHEN itemid IN (211, 220045) AND valuenum > 0 AND valuenum < 300 --OK
        THEN 'HEART RATE'
      WHEN itemid IN (51, 442, 455, 6701, 220179, 220050) AND valuenum > 0 AND valuenum < 400 --OK
        THEN 'SYSTOLIC BP'
      WHEN itemid IN (8368, 8440, 8441, 8555, 220180, 220051) AND valuenum > 0 AND valuenum < 300 --OK
        THEN 'DIASTOLIC BP'
      WHEN itemid IN (223761, 678) AND valuenum > 70 AND valuenum < 120 --OK
        THEN 'TEMPERATURE' -- converted to degC in valuenum call
      WHEN itemid IN (223762, 676) AND valuenum > 10 AND valuenum < 50 --OK
        THEN 'TEMPERATURE'
      WHEN itemid IN (223835, 3420, 3422, 190) --AND valuenum > 0 AND valuenum < 100 --OK
        THEN 'FiO2'
      ELSE NULL END                                                       AS measurement_name,
      case
          when itemid = 223835
            then case
              when valuenum > 0 and valuenum <= 1
                then valuenum * 100
              -- improperly input data - looks like O2 flow in litres
              when valuenum > 1 and valuenum < 21
                then null
              when valuenum >= 21 and valuenum <= 100
                then valuenum
              else null end -- unphysiological
        when itemid in (3420, 3422)
        -- all these values are well formatted
            then valuenum
        when itemid = 190 and valuenum > 0.20 and valuenum < 1
        -- well formatted but not in %
            then valuenum * 100
        WHEN itemid IN (223761, 678)
          then (c.valuenum -32)/1.8 --convert F to C
      else valuenum end                                                          AS value,
      EXTRACT(EPOCH FROM c.charttime - i.intime) / 60 / 60                AS icu_time_hr
    FROM mimiciii.icustays i
      JOIN mimiciii.patients p ON i.subject_id = p.subject_id
      JOIN mimiciii.admissions ad ON ad.hadm_id = i.hadm_id AND ad.subject_id = i.subject_id
      JOIN mimiciii.diagnoses_icd icd on ad.hadm_id = icd.hadm_id AND ad.subject_id = icd.subject_id
      JOIN mimiciii.services ser on ad.hadm_id = ser.hadm_id AND ad.subject_id = ser.subject_id
      LEFT JOIN mimiciii.chartevents c
        ON i.icustay_id = c.icustay_id
           AND c.error IS DISTINCT FROM 1
           AND c.itemid IN
               (
                 -- HEART RATE
                 211, --"Heart Rate"
                      220045, --"Heart Rate"

                      -- Systolic/diastolic

                      51, --	Arterial BP [Systolic]
                      442, --	Manual BP [Systolic]
                      455, --	NBP [Systolic]
                      6701, --	Arterial BP #2 [Systolic]
                      220179, --	Non Invasive Blood Pressure systolic
                      220050, --	Arterial Blood Pressure systolic

                      8368, --	Arterial BP [Diastolic]
                      8440, --	Manual BP [Diastolic]
                      8441, --	NBP [Diastolic]
                            8555, --	Arterial BP #2 [Diastolic]
                            220180, --	Non Invasive Blood Pressure diastolic
                            220051, --	Arterial Blood Pressure diastolic



                 -- TEMPERATURE
                 223762, -- "Temperature Celsius"
                 676, -- "Temperature C"
                 223761, -- "Temperature Fahrenheit"
                 678, --	"Temperature F"

                 --Glasgow Coma Scale

                 723, --GCSVERBAL
                 223900, --Verbal Response
                 454, --GCSMOTOR
                 223901, --Motor Response
                 184, --GCSEYES
                 220739, --Eye Opening
                 --FiO2
                 223835, --Inspired O2 Fraction (FiO2)
                 3420, --FiO2
                 3422, --FiO2 [Meas]
                 190 --FiO2 set
               )
           AND c.charttime BETWEEN (i.intime) AND (i.intime + INTERVAL '2' DAY)
    --JOIN mimiciii.d_items d on d.itemid = c.itemid

    --WHERE i.subject_id = 6
    WHERE i.los >= 2
    --ORDER BY c.charttime ASC


    UNION
    --now lab tests stuff

    SELECT
      i.subject_id,
      i.hadm_id,
      EXTRACT(EPOCH FROM i.intime - p.dob) / 60.0 / 60.0 / 24.0 / 365.242 AS age,
      CASE
      WHEN ad.ADMISSION_TYPE = 'ELECTIVE' THEN 1
      ELSE 0 END                                                          AS elective,
      CASE
      WHEN lower(ser.CURR_SERVICE) like '%surg%' then 1
      ELSE 0 END                                                          AS surgical,
      CASE
      WHEN icd9_code BETWEEN '042' AND '0449'
        THEN 1
		  ELSE 0 END                                                          AS AIDS      /* HIV and AIDS */,
      CASE
      WHEN icd9_code BETWEEN '1960' AND '1991' THEN 1
      WHEN icd9_code BETWEEN '20970' AND '20975' THEN 1
      WHEN icd9_code = '20979' THEN 1
      WHEN icd9_code = '78951' THEN 1
      ELSE 0 END                                                         AS METASTATIC_CANCER,
      CASE
      WHEN icd9_code BETWEEN '20000' AND '20238' THEN 1 -- lymphoma
      WHEN icd9_code BETWEEN '20240' AND '20248' THEN 1 -- leukemia
      WHEN icd9_code BETWEEN '20250' AND '20302' THEN 1 -- lymphoma
      WHEN icd9_code BETWEEN '20310' AND '20312' THEN 1 -- leukemia
      WHEN icd9_code BETWEEN '20302' AND '20382' THEN 1 -- lymphoma
      WHEN icd9_code BETWEEN '20400' AND '20522' THEN 1 -- chronic leukemia
      WHEN icd9_code BETWEEN '20580' AND '20702' THEN 1 -- other myeloid leukemia
      WHEN icd9_code BETWEEN '20720' AND '20892' THEN 1 -- other myeloid leukemia
      WHEN icd9_code = '2386 ' THEN 1 -- lymphoma
      WHEN icd9_code = '2733 ' THEN 1 -- lymphoma
      ELSE 0 END                                                         AS LYMPHOMA,
      RANK()
      OVER (
        PARTITION BY i.subject_id
        ORDER BY i.intime )                                               AS icustay_id_order,
      CASE
      WHEN ad.deathtime BETWEEN i.intime AND i.outtime
        THEN 1
      ELSE 0 END                                                          AS mort_icu
      --, d.label as variable_name
      ,
      CASE
      WHEN itemid IN (950824, 50824, 50983) --OK
        THEN 'SODIUM'
      WHEN le.itemid = 50882  --OK
        THEN 'BICARBONATE'
      WHEN le.itemid = 50885  --OK
        THEN 'BILIRUBIN'
      WHEN itemid IN (50822, 50971)   --OK
        THEN 'POTASSIUM'
      WHEN itemid = 51006 --OK
        THEN 'BUN'
      WHEN itemid IN (51300, 51301) --OK
        THEN 'WBC'
      WHEN itemid = 50821 --OK
        THEN 'PO2'
      WHEN itemid = 50816 --OK
        THEN 'FiO2'
      ELSE NULL END                                                       AS measurement_name,
      CASE
      WHEN le.itemid = 50882 AND le.valuenum > 10000
        THEN NULL -- mEq/L 'BICARBONATE'
      WHEN le.itemid = 50885 AND le.valuenum > 150
        THEN NULL -- mg/dL 'BILIRUBIN'
      WHEN le.itemid = 50822 AND le.valuenum > 30
        THEN NULL -- mEq/L 'POTASSIUM'
      WHEN le.itemid = 50971 AND le.valuenum > 30
        THEN NULL -- mEq/L 'POTASSIUM'
      WHEN le.itemid = 50824 AND le.valuenum > 200
        THEN NULL -- mEq/L == mmol/L 'SODIUM'
      WHEN le.itemid = 50983 AND le.valuenum > 200
        THEN NULL -- mEq/L == mmol/L 'SODIUM'
      WHEN le.itemid = 51006 AND le.valuenum > 300
        THEN NULL -- 'BUN'
      WHEN le.itemid = 51300 AND le.valuenum > 1000
        THEN NULL -- 'WBC'
      WHEN le.itemid = 51301 AND le.valuenum > 1000
        THEN NULL -- 'WBC'
        WHEN le.itemid = 50816 AND le.valuenum > 100
        THEN NULL -- 'FiO2'
      WHEN le.itemid = 50821 AND le.valuenum > 800
        THEN NULL -- 'PO2'
      ELSE le.valuenum
      END                                                                 AS value,
      EXTRACT(EPOCH FROM le.charttime - i.intime) / 60 / 60               AS icu_time_hr
    FROM mimiciii.icustays i
      JOIN mimiciii.patients p ON i.subject_id = p.subject_id
      JOIN mimiciii.admissions ad ON ad.hadm_id = i.hadm_id AND ad.subject_id = i.subject_id
      JOIN mimiciii.diagnoses_icd icd on ad.hadm_id = icd.hadm_id AND ad.subject_id = icd.subject_id
      JOIN mimiciii.services ser on ad.hadm_id = ser.hadm_id AND ad.subject_id = ser.subject_id
      LEFT JOIN mimiciii.labevents le
        ON i.subject_id = le.subject_id
           AND i.hadm_id = le.hadm_id
           AND le.itemid IN
               (
                 -- comment is: LABEL | CATEGORY | FLUID | NUMBER OF ROWS IN LABEVENTS
                 50882, -- BICARBONATE | CHEMISTRY | BLOOD | 780733
                50885, -- BILIRUBIN, TOTAL | CHEMISTRY | BLOOD | 238277
                 50971, -- POTASSIUM | CHEMISTRY | BLOOD | 845825
                 50822, -- POTASSIUM, WHOLE BLOOD | BLOOD GAS | BLOOD | 192946
                 50983, -- SODIUM | CHEMISTRY | BLOOD | 808489
                 50824, -- SODIUM, WHOLE BLOOD | BLOOD GAS | BLOOD | 71503
                 950824, -- SODIUM
                 51006, -- UREA NITROGEN | CHEMISTRY | BLOOD | 791925
                 51301, -- WHITE BLOOD CELLS | HEMATOLOGY | BLOOD | 753301
                 51300,  -- WBC COUNT | HEMATOLOGY | BLOOD | 2371
                 50821,  -- PO2 | | |
                 50816  -- FiO2 | | |
               )
           AND le.valuenum IS NOT NULL
           AND le.valuenum > 0 -- lab values cannot be 0 and cannot be negative
           AND le.charttime BETWEEN (i.intime) AND (i.intime + INTERVAL '2' DAY)
    WHERE i.los >= 2
    --now urine stuff
    UNION

    SELECT
      i.subject_id,
      i.hadm_id,
      EXTRACT(EPOCH FROM i.intime - p.dob) / 60.0 / 60.0 / 24.0 / 365.242 AS age,
      CASE
      WHEN ad.ADMISSION_TYPE = 'ELECTIVE' THEN 1
      ELSE 0 END                                                          AS elective,
      CASE
      WHEN lower(ser.CURR_SERVICE) like '%surg%' then 1
      ELSE 0 END                                                          AS surgical,
      CASE
      WHEN icd9_code BETWEEN '042' AND '0449'
        THEN 1
		  ELSE 0 END                                                          AS AIDS      /* HIV and AIDS */,
      CASE
      WHEN icd9_code BETWEEN '1960' AND '1991' THEN 1
      WHEN icd9_code BETWEEN '20970' AND '20975' THEN 1
      WHEN icd9_code = '20979' THEN 1
      WHEN icd9_code = '78951' THEN 1
      ELSE 0 END                                                         AS METASTATIC_CANCER,
      CASE
      WHEN icd9_code BETWEEN '20000' AND '20238' THEN 1 -- lymphoma
      WHEN icd9_code BETWEEN '20240' AND '20248' THEN 1 -- leukemia
      WHEN icd9_code BETWEEN '20250' AND '20302' THEN 1 -- lymphoma
      WHEN icd9_code BETWEEN '20310' AND '20312' THEN 1 -- leukemia
      WHEN icd9_code BETWEEN '20302' AND '20382' THEN 1 -- lymphoma
      WHEN icd9_code BETWEEN '20400' AND '20522' THEN 1 -- chronic leukemia
      WHEN icd9_code BETWEEN '20580' AND '20702' THEN 1 -- other myeloid leukemia
      WHEN icd9_code BETWEEN '20720' AND '20892' THEN 1 -- other myeloid leukemia
      WHEN icd9_code = '2386 ' THEN 1 -- lymphoma
      WHEN icd9_code = '2733 ' THEN 1 -- lymphoma
      ELSE 0 END                                                         AS LYMPHOMA,
      RANK()
      OVER (
        PARTITION BY i.subject_id
        ORDER BY i.intime )                                               AS icustay_id_order,
      CASE
      WHEN ad.deathtime BETWEEN i.intime AND i.outtime
        THEN 1
      ELSE 0 END                                                          AS mort_icu,
      'URINE OUTPUT'                                               AS measurement_name,
      -- we consider input of GU irrigant as a negative volume
      CASE when oe.itemid = 227488
        then -1 * oe.value
      ELSE oe.value END                                                       AS value,
      EXTRACT(EPOCH FROM oe.charttime - i.intime) / 60 / 60                AS icu_time_hr
    FROM mimiciii.icustays i
      JOIN mimiciii.patients p ON i.subject_id = p.subject_id
      JOIN mimiciii.admissions ad ON ad.hadm_id = i.hadm_id AND ad.subject_id = i.subject_id
      JOIN mimiciii.diagnoses_icd icd on ad.hadm_id = icd.hadm_id AND ad.subject_id = icd.subject_id
      JOIN mimiciii.services ser on ad.hadm_id = ser.hadm_id AND ad.subject_id = ser.subject_id
      LEFT JOIN mimiciii.outputevents oe
        ON i.icustay_id = oe.icustay_id
           AND oe.iserror IS DISTINCT FROM 1
           AND oe.itemid IN
               (
                 -- these are the most frequently occurring urine output observations in CareVue
                 40055, -- "Urine Out Foley"
                43175, -- "Urine ."
                        40069, -- "Urine Out Void"
                        40094, -- "Urine Out Condom Cath"
                        40715, -- "Urine Out Suprapubic"
                        40473, -- "Urine Out IleoConduit"
                        40085, -- "Urine Out Incontinent"
                        40057, -- "Urine Out Rt Nephrostomy"
                        40056, -- "Urine Out Lt Nephrostomy"
                        40405, -- "Urine Out Other"
                        40428, -- "Urine Out Straight Cath"
                               40086, --	Urine Out Incontinent
                               40096, -- "Urine Out Ureteral Stent #1"
                               40651, -- "Urine Out Ureteral Stent #2"

                               -- these are the most frequently occurring urine output observations in MetaVision
                               226559, -- "Foley"
                               226560, -- "Void"
                               226561, -- "Condom Cath"
                               226584, -- "Ileoconduit"
                               226563, -- "Suprapubic"
                               226564, -- "R Nephrostomy"
                               226565, -- "L Nephrostomy"
                 226567, --	Straight Cath
                 226557, -- R Ureteral Stent
                 226558, -- L Ureteral Stent
                 227488, -- GU Irrigant Volume In
                 227489  -- GU Irrigant/Urine Volume Out
               )
           AND oe.value < 5000 -- sanity check on urine value
           AND oe.charttime BETWEEN (i.intime) AND (i.intime + INTERVAL '2' DAY)
    WHERE i.los >= 2
  )
  SELECT *
  FROM cohort
  WHERE icustay_id_order = 1 AND age > 16
  ORDER BY subject_id, icu_time_hr
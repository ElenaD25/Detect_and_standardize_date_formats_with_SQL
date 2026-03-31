
-- Detect existing date formats in rebel_date_format
WITH base AS (
  SELECT
    id,
    rebel_date_format,
    CASE
      WHEN REGEXP_LIKE(rebel_date_format, '^[0-9]{4}-[0-9]{2}-[0-9]{2}$') THEN 'YYYY-MM-DD'
      WHEN REGEXP_LIKE(rebel_date_format, '^[0-9]{4}/[0-9]{2}/[0-9]{2}$') THEN 'YYYY/MM/DD'
      WHEN REGEXP_LIKE(rebel_date_format, '^[0-9]{4}\.[0-9]{2}\.[0-9]{2}$') THEN 'YYYY.MM.DD'
      WHEN REGEXP_LIKE(rebel_date_format, '^[0-9]{2}-[0-9]{2}-[0-9]{4}$') THEN 'DD-MM-YYYY'
      WHEN REGEXP_LIKE(rebel_date_format, '^[0-9]{2}/[0-9]{2}/[0-9]{4}$') THEN 'DD/MM/YYYY'
      WHEN REGEXP_LIKE(rebel_date_format, '^[0-9]{2}\.[0-9]{2}\.[0-9]{4}$') THEN 'DD.MM.YYYY'
      WHEN REGEXP_LIKE(UPPER(rebel_date_format), '^[0-9]{1,2}-[A-Z]{3}-[0-9]{4}$') THEN 'DD-MON-YYYY'
      WHEN REGEXP_LIKE(UPPER(rebel_date_format), '^[0-9]{4}-[A-Z]{3}-[0-9]{1,2}$') THEN 'YYYY-MON-DD'
      WHEN REGEXP_LIKE(rebel_date_format, '^[0-9]{4}-[0-9]{2}-[0-9]{2}[ T][0-9]{2}:[0-9]{2}(:[0-9]{2})?(\.[0-9]+)?(Z|[+-][0-9]{2}:[0-9]{2})?$')
        THEN 'YYYY-MM-DD[ T]HH:MI(:SS)[.FF][TZ]'
      WHEN REGEXP_LIKE(rebel_date_format, '^[0-9]{8}$') THEN '8 caractere (YYYYMMDD / DDMMYYYY)'
      WHEN REGEXP_LIKE(rebel_date_format, '^[0-9]{6}$') THEN '6 caractere (YYMMDD / DDMMYY)'
      WHEN REGEXP_LIKE(rebel_date_format, '.*[A-Za-z].*') THEN 'contine litere'
      ELSE 'other format'
    END AS detected_format
  FROM TABLE1
  WHERE rebel_date_format IS NOT NULL
)

-- Isolate records that require standardization
,src AS (
  SELECT
    id,
    rebel_date_format AS rebel_date_format_raw,
    TRIM(rebel_date_format) AS raw_date
  FROM base
  WHERE detected_format = 'other format'
)

-- Extract numeric components from the date string (order depends on input format)
-- part1 = first numeric group
-- part2 = second numeric group
-- part3 = third numeric group 
,parts AS (
  SELECT
    id,
    rebel_date_format_raw,
    raw_date,
    REGEXP_SUBSTR(raw_date, '[0-9]+', 1, 1) AS part1,
    REGEXP_SUBSTR(raw_date, '[0-9]+', 1, 2) AS part2,
    REGEXP_SUBSTR(raw_date, '[0-9]+', 1, 3) AS part3
  FROM src
)

-- Rebuild dates into a consistent DD-MM-YYYY format for validation and conversion
,transf AS (
  SELECT
    id,
    rebel_date_format_raw,
    raw_date,
    CASE
      WHEN raw_date IS NOT NULL
       AND REGEXP_LIKE(raw_date, '^[0-9]{4}[^0-9][0-9]{1,2}[^0-9][0-9]{1,2}$')
      THEN LPAD(part3,2,'0') || '-' || LPAD(part2,2,'0') || '-' || part1
 
      WHEN raw_date IS NOT NULL
       AND REGEXP_LIKE(raw_date, '^[0-9]{1,2}[^0-9][0-9]{1,2}[^0-9][0-9]{4}$')
      THEN LPAD(part1,2,'0') || '-' || LPAD(part2,2,'0') || '-' || part3
 
      WHEN raw_date IS NOT NULL
       AND REGEXP_LIKE(raw_date, '^[0-9]{1,2}[^0-9][0-9]{6}$')
      THEN LPAD(part1,2,'0') || '-' || SUBSTR(part2,1,2) || '-' || SUBSTR(part2,3,4)
 
      WHEN raw_date IS NOT NULL
       AND REGEXP_LIKE(raw_date, '^[0-9]{4}[^0-9][0-9]{4}$')
      THEN SUBSTR(part1,1,2) || '-' || SUBSTR(part1,3,2) || '-' || part2
 
      WHEN raw_date IS NOT NULL
       AND REGEXP_LIKE(raw_date, '^[0-9]{1,2}[^0-9][0-9]{1,2}[^0-9][0-9]{2}$')
      THEN LPAD(part1,2,'0') || '-' || LPAD(part2,2,'0') || '-' || ('20' || LPAD(part3,2,'0'))
 
      WHEN raw_date IS NOT NULL
       AND REGEXP_LIKE(raw_date, '^[0-9]{8}$')
       AND TO_NUMBER(SUBSTR(raw_date,1,4)) BETWEEN 1000 AND 9999
      THEN SUBSTR(raw_date,7,2) || '-' || SUBSTR(raw_date,5,2) || '-' || SUBSTR(raw_date,1,4)
 
      WHEN raw_date IS NOT NULL
       AND REGEXP_LIKE(raw_date, '^[0-9]{8}$')
      THEN SUBSTR(raw_date,1,2) || '-' || SUBSTR(raw_date,3,2) || '-' || SUBSTR(raw_date,5,4)
  
      ELSE NULL
    END AS agreed_format
  FROM parts
)

-- Final step: validate and convert standardized string to DATE format (YYYY-MM-DD)
SELECT
  id,
  rebel_date_format_raw,
  CASE
    WHEN agreed_format IS NOT NULL
     AND VALIDATE_CONVERSION(agreed_format AS DATE, 'DD-MM-YYYY') = 1
    THEN TO_CHAR(TO_DATE(agreed_format, 'DD-MM-YYYY'), 'YYYY-MM-DD')
    ELSE NULL
  END AS rebel_date_format_standardized
FROM transf
ORDER BY id
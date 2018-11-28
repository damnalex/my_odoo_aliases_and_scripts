UPDATE ir_cron SET active=false;
UPDATE ir_mail_server SET active=false;
UPDATE ir_config_parameter SET value = '2042-01-01 00:00:00' WHERE key = 'database.expiration_date';
UPDATE ir_config_parameter SET value = 'd3ac3a44-6718-4762-8ae6-45b4d4cecd7f' WHERE key = 'database.uuid';  -- change de value if there is multiple databases to neuter
INSERT INTO ir_mail_server(active,name,smtp_host,smtp_port,smtp_encryption) VALUES (true,'mailcatcher','localhost',1025,false);
UPDATE res_users SET password=login;
DELETE FROM ir_attachment WHERE name like '%assets_%';

DO $$
    BEGIN
        UPDATE auth_oauth_provider SET enabled = false;
    EXCEPTION
        WHEN undefined_table THEN
    END;
$$;

SELECT u.id,login,p.name,share FROM res_users u JOIN res_partner p ON u.partner_id=p.id WHERE u.active=true ORDER BY share ASC,u.id ASC LIMIT 15

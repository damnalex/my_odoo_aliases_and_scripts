UPDATE ir_cron SET active=false;
UPDATE ir_mail_server SET active=false;
UPDATE ir_config_parameter SET value = '2042-01-01 00:00:00' WHERE key = 'database.expiration_date';
UPDATE ir_config_parameter SET value = 'd3ac3a44-6718-4762-8ae6-45b4d4cecd7f' WHERE key = 'database.uuid';  -- change de value if there is multiple databases to neuter
INSERT INTO ir_mail_server(active,name,smtp_host,smtp_port,smtp_encryption) VALUES (true,'mailcatcher','localhost',1025,false);
UPDATE res_users SET password=login;
DELETE FROM ir_attachment WHERE name like '%assets_%';

INSERT INTO ir_config_parameter(key, value)
VALUES ('iap.endpoint', 'https://iap-sandbox.odoo.com')
ON CONFLICT (key) DO UPDATE SET
value = 'https://iap-sandbox.odoo.com';

UPDATE ir_config_parameter SET value = 'https://iap-services-test.odoo.com' WHERE key = 'snailmail.endpoint';
UPDATE ir_config_parameter SET value = 'https://iap-services-test.odoo.com' WHERE key = 'reveal.endpoint';
UPDATE ir_config_parameter SET value = 'https://iap-services-test.odoo.com' WHERE key = 'iap.partner_autocomplete.endpoint';
UPDATE ir_config_parameter SET value = 'https://iap-services-test.odoo.com' WHERE key = 'sms.endpoint';

DO $$
    BEGIN
        UPDATE auth_oauth_provider SET enabled = false;
    EXCEPTION
        WHEN undefined_table OR undefined_column THEN
    END;
$$;

DO $$
    BEGIN
        UPDATE
            res_company
        SET
            yodlee_access_token = NULL,
            yodlee_user_password = NULL,
            yodlee_user_access_token = NULL;
    EXCEPTION
        WHEN undefined_table OR undefined_column THEN
    END;
$$;

DO $$
    BEGIN
        UPDATE
            account_online_provider
        SET
            provider_account_identifier = NULL;
    EXCEPTION
        WHEN undefined_table OR undefined_column THEN
    END;
$$;

DO $$
    BEGIN
        UPDATE delivery_carrier set active='f';
    EXCEPTION
        WHEN undefined_table OR undefined_column THEN
    END;
$$;

DO $$
    BEGIN
        UPDATE payment_acquirer set environment='test';
    EXCEPTION
        WHEN undefined_table OR undefined_column THEN
    END;
$$;

SELECT u.id,login,p.name,share FROM res_users u JOIN res_partner p ON u.partner_id=p.id WHERE u.active=true ORDER BY share ASC,u.id ASC LIMIT 15

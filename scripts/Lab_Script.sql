
--Step 2.1 - Create Security Integration
--use account admin to create snowservices ingress oauth
use role accountadmin;
create security integration if not exists snowservices_ingress_oauth
  type=oauth
  oauth_client=snowservices_ingress
  enabled=true;

--Step 3.1 - Create NASPCS role and Grant Privileges
--these series of steps create and grant the naspcs role which will be our 'provider' role 
use role accountadmin;
create role if not exists naspcs_role;
grant role naspcs_role to role accountadmin;
grant create integration on account to role naspcs_role;
grant create compute pool on account to role naspcs_role;
grant create warehouse on account to role naspcs_role;
grant create database on account to role naspcs_role;
grant create application package on account to role naspcs_role;
grant create application on account to role naspcs_role with grant option;
grant bind service endpoint on account to role naspcs_role;

--Step 3.2 - Create SCPS_APP Database to Store Application Files and Container Images
--after creating the naspcs role we will switch to it and set up our environment 
--the spcs_app database will house our snowpark container services images 
--it will also be where we upload the required files to create a native app package
use role naspcs_role;
create database if not exists spcs_app;
create schema if not exists spcs_app.napp;
create stage if not exists spcs_app.napp.app_stage;
create image repository if not exists spcs_app.napp.img_repo;
create warehouse if not exists wh_nap with warehouse_size='xsmall';

--Step 4.1 - Create NAC role and Grant Privileges
--now that we've created our application package we need to set up a role to imitate a 'consumer' installing the native app
use role accountadmin;
create role if not exists nac;
grant role nac to role accountadmin;
create warehouse if not exists wh_nac with warehouse_size='xsmall';
grant usage on warehouse wh_nac to role nac with grant option;
grant imported privileges on database snowflake_sample_data to role nac;
grant create database on account to role nac;
grant bind service endpoint on account to role nac with grant option;
grant create compute pool on account to role nac;
grant create application on account to role nac;

--Step 4.2 - Create Consumer Test Data Database
--with our consumer role created we need to set up a database that will hold the data to be consumed by our application
use role nac;
create database if not exists nac_test;
create schema if not exists nac_test.data;
use schema nac_test.data;
create view if not exists orders as select * from snowflake_sample_data.tpch_sf10.orders;

--Step 5.1 - Get Image Repository URL
--once we've created the database to store our images and na files we can find the image repository url
show image repositories in schema spcs_app.napp;

--Step 6.1 - Create Application Package and Grant Consumer Role Privileges
--after we've uploaded all of the images and files for the native app we need to create our native app package
--after creating the package we'll add a version to it using all of the files upload to our spcs_app database
use role naspcs_role;
create application package spcs_app_pkg;
alter application package spcs_app_pkg add version v1 using @spcs_app.napp.app_stage;
grant install, develop on application package spcs_app_pkg to role nac;

--Step 7.1 - Install Native App
--at this point we can switch back to our consumer role and create the application in our account using the application package
--this is simulating the experience of what would otherwise be the consumer installing the app in a separate account
use role nac;
create application spcs_app_instance from application package spcs_app_pkg using version v1;

--Step 7.2 - Create Compute Pool and Grant Privileges
--after succesfully installing the application we need to create a compute pool that the application will use to run the container images 
create  compute pool pool_nac for application spcs_app_instance
    min_nodes = 1 max_nodes = 1
    instance_family = cpu_x64_xs
    auto_resume = true;

grant usage on compute pool pool_nac to application spcs_app_instance;
grant usage on warehouse wh_nac to application spcs_app_instance;
grant bind service endpoint on account to application spcs_app_instance;

--Step 7.3 - Start App Service
--finally we can use the store procedure shipped with the application to start the app 
--we pass in the pool_nac compute pool where the images will run and the wh_nac warehouse which the app will use to execute queries on snowflake
call spcs_app_instance.app_public.start_app('pool_nac', 'wh_nac');

--it takes a few minutes to get the app up and running but you can use the following function to find the app url when it is fully deployed
call spcs_app_instance.app_public.app_url();


--Step 8.1 - Clean Up
--clean up consumer objects
use role nac;
drop application spcs_app_instance;
drop warehouse wh_nac;
drop compute pool pool_nac;
drop database nac_test;

--clean up provider objects
use role naspcs_role;
drop application package spcs_app_pkg;
drop database spcs_app;
drop warehouse wh_nap;

--clean up prep objects
use role accountadmin;
drop role naspcs_role;
drop role nac;


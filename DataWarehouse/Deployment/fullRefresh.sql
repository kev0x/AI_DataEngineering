-- DuckDB deployment uses Deployment/deployWarehouse.py with --reset for full refresh.
-- This file documents the SQL operation performed by that deployment mode.

drop schema if exists Gold cascade;
drop schema if exists Silver cascade;
drop schema if exists Bronze cascade;


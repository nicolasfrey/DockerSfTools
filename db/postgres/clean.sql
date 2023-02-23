create or replace function clear_db() returns void as $$
declare
    statements_schema cursor for
        select
            s.schema_name
        from
            information_schema.schemata s
        where
            s.schema_name not similar to '(pg|information)\_[a-zA-Z0-9_]*'
            and s.schema_name <> 'public';
    statements_public cursor for
        select
            t.table_name
        from
            information_schema."tables" t
        where
            t.table_type = 'BASE TABLE'
            and t.table_schema = 'public';
    statements_fn cursor for
        select
            case p.prokind
                when 'f' then 'function'
                when 'p' then 'procedure'
            end as fn_type,
            p.proname as fn_name
        from
            pg_proc p
        left join pg_namespace n on p.pronamespace = n.oid
        left join pg_language l on p.prolang = l.oid
        left join pg_type t on t.oid = p.prorettype
        where
            n.nspname not in ('pg_catalog', 'information_schema')
            and p.probin is null;
begin
    for stmt_s in statements_schema loop
        execute 'drop schema ' || quote_ident(stmt_s.schema_name) || ' cascade;';
    end loop;
    for stmt_p in statements_public loop
        execute 'drop table ' || quote_ident(stmt_p.table_name) || ' cascade;';
    end loop;
    for stmt_f in statements_fn loop
        execute 'drop ' || stmt_f.fn_type || ' ' || quote_ident(stmt_f.fn_name) || ';';
    end loop;
end;
$$ language plpgsql;
select public.clear_db();
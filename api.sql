create extension if not exists plv8;

drop function if exists save_document(varchar, jsonb);
drop function if exists create_document_table(varchar);
drop function if exists update_search(varchar, int);
drop function find_document(varchar, int);
drop function if exists find_document(varchar, varchar, varchar);
drop function if exists filter_documents(varchar, varchar);
drop function if exists search_documents(varchar, varchar);


create function create_document_table(name varchar, out boolean)
as $$
  var sql = "create table " + name + "(" +
    "id serial primary key," +
    "body jsonb not null," +
    "search tsvector," +
    "created_at timestamptz default now() not null," +
    "updated_at timestamptz default now() not null);";

  plv8.execute(sql);
  plv8.execute("create index idx_" + name + " on docs using GIN(body jsonb_path_ops)");
  plv8.execute("create index idx_" + name + "_search on docs using GIN(search)");
  return true;
$$ language plv8;

create function update_search(tbl varchar, id int)
returns boolean
as $$
  //get the record
  var found = plv8.execute("select body from " + tbl + " where id=$1",id)[0];
  if(found){
    var doc = JSON.parse(found.body);
    var searchFields = ["name","email","first","first_name","last","last_name","description","title"];
    var searchVals = [];
    for(var key in doc){
      if(searchFields.indexOf(key) > -1){
        searchVals.push(doc[key]);
      }
    };

    if(searchVals.length > 0){
      var updateSql = "update " + tbl + " set search = to_tsvector($1) where id =$2";
      plv8.execute(updateSql, searchVals.join(" "), id);
    }
    return true;
  }else{
    return false;
  }

$$ language plv8;

create function save_document(tbl varchar, doc_string jsonb)
returns jsonb
as $$
  var doc = JSON.parse(doc_string);

  var exists = plv8.execute("select table_name from information_schema.tables where table_name = $1", tbl)[0];
  if(!exists){
    plv8.execute("select create_document_table('" + tbl + "');");
  }

  var executeSql = function(theDoc){
    var result = null;
    var id = theDoc.id;
    var toSave = JSON.stringify(theDoc);

    if(id){
      result=plv8.execute("update " + tbl + " set body=$1, updated_at = now() where id=$2 returning *;",toSave, id);
    }else{
      result=plv8.execute("insert into " + tbl + "(body) values($1) returning *;", toSave);

      id = result[0].id;
      //put the id back on the document
      theDoc.id = id;
      //resave it
      result = plv8.execute("update " + tbl + " set body=$1 where id=$2 returning *;",JSON.stringify(theDoc),id);
    }
    plv8.execute("select update_search($1,$2)", tbl, id);
    return result ? result[0].body : null;
  }
  var out = null;
  if(doc instanceof Array){
    var bulkResult = [];
    for(var i = 0; i < doc.length;i++){
      executeSql(doc[i]);
    }
    out = JSON.stringify({success : true, count : i});
  }else{
    out = executeSql(doc);
  }
  return out;
$$ language plv8;

create function find_document(tbl varchar, id int, out jsonb)
as $$
  //find by the id of the row
  var result = plv8.execute("select * from " + tbl + " where id=$1;",id);
  return result[0] ? result[0].body : null;

$$ language plv8;

create function find_document(tbl varchar, criteria varchar, orderby varchar)
returns jsonb
as $$
  var valid = JSON.parse(criteria);//this will throw if it invalid
  var results = plv8.execute("select body from " + tbl + " where body @> $1 order by body ->> '" + orderby + "' limit 1;",criteria);
  return results[0] ? results[0].body : null
$$ language plv8;

create function filter_documents(tbl varchar, criteria varchar)
returns setof jsonb
as $$
  var valid = JSON.parse(criteria);//this will throw if it invalid
  var results = plv8.execute("select body from " + tbl + " where body @> $1;",criteria);
  var out = [];
  for(var i = 0;i < results.length; i++){
    out.push(results[i].body);
  }
  return out;
$$ language plv8;

create function search_documents(tbl varchar, query varchar)
returns setof jsonb
as $$
  var sql = "select body, ts_rank_cd(search,to_tsquery($1)) as rank from " + tbl +
    " where search @@ to_tsquery($1) " +
    " order by rank desc;"
  var results = plv8.execute(sql,query);
  var out = [];
  for(var i = 0; i < results.length; i++){
    out.push(results[i].body);
  }
  return out;
$$ language plv8;

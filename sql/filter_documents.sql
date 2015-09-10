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

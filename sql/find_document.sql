create function find_document(tbl varchar, id int, out jsonb)
as $$
  //find by the id of the row
  var result = plv8.execute("select * from " + tbl + " where id=$1;",id);
  return result[0] ? result[0].body : null;

$$ language plv8;

create function find_document(tbl varchar, criteria varchar, orderby varchar default 'id')
returns jsonb
as $$
  var valid = JSON.parse(criteria);//this will throw if it invalid
  var results = plv8.execute("select body from " + tbl + " where body @> $1 order by body ->> '" + orderby + "' limit 1;",criteria);
  return results[0] ? results[0].body : null
$$ language plv8;

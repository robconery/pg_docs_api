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

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

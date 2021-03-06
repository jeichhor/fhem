var consConn;

var isFF = (navigator.userAgent.toLowerCase().indexOf('firefox') > -1);
var consFilter, consTxt;

log("Console is opening");

function
consUpdate()
{
  if(consConn.readyState == 4) {
    FW_errmsg("Connection lost, trying a reconnect every 5 seconds.");
    setTimeout(consFill, 5000);
    return; // some problem connecting
  }

  if(consConn.readyState != 3)
    return;

  var el = document.getElementById("console");
  if(el) {
    el.innerHTML=consTxt+consConn.responseText;
    el.scrollTop = el.scrollHeight;    
  }
}

function
consFill()
{
  FW_errmsg("");

  consConn = new XMLHttpRequest();
  var query = document.location.pathname+"?XHR=1"+
       "&inform=type=raw;filter="+consFilter+
       "&timestamp="+new Date().getTime();
  query = addcsrf(query);
  consConn.open("GET", query, true);
  consConn.onreadystatechange = consUpdate;
  consConn.send(null);
}

function
consStart()
{
  var el = document.getElementById("console");

  consFilter = el.getAttribute("filter");
  if(consFilter == undefined)
    consFilter = ".*";
  consTxt = el.innerHTML;
  setTimeout("consFill()", 1000);
}

window.onload = consStart;

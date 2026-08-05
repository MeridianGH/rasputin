dns {
  nameserver = ["unbound"];  # Hostname support requires Rspamd 3.14+
  timeout = 1s;
  sockets = 16;
}

check_all_filters = true;

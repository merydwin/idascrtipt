%ignore mutable_graph_t;
%ignore graph_visitor_t;
%ignore abstract_graph_t;
%include "graph.hpp"

%{
//<code(py_graph)>
class py_graph_t : public py_customidamemo_t
{
  typedef py_customidamemo_t inherited;

protected:

  virtual void node_info_modified(int n, const node_info_t *ni, uint32 flags)
  {
    if ( ni == NULL )
    {
      node_cache.erase(n);
    }
    else
    {
      nodetext_cache_t *c = node_cache.get(n);
      if ( c != NULL )
      {
        if ( (flags & NIF_TEXT) == NIF_TEXT )
          c->text = ni->text;
        if ( (flags & NIF_BG_COLOR) == NIF_BG_COLOR )
          c->bgcolor = ni->bg_color;
      }
    }
  }

  void collect_class_callbacks_ids(callbacks_ids_t *out);

private:
  enum
  {
    GRCODE_HAVE_USER_HINT       = 0x00010000,
    GRCODE_HAVE_CLICKED         = 0x00020000,
    GRCODE_HAVE_DBL_CLICKED     = 0x00040000,
    GRCODE_HAVE_GOTFOCUS        = 0x00080000,
    GRCODE_HAVE_LOSTFOCUS       = 0x00100000,
    GRCODE_HAVE_CHANGED_CURRENT = 0x00200000,
    GRCODE_HAVE_COMMAND         = 0x00400000
  };
  struct nodetext_cache_t
  {
    qstring text;
    bgcolor_t bgcolor;
    nodetext_cache_t(const nodetext_cache_t &rhs): text(rhs.text), bgcolor(rhs.bgcolor) { }
    nodetext_cache_t(const char *t, bgcolor_t c): text(t), bgcolor(c) { }
    nodetext_cache_t() { }
  };

  class nodetext_cache_map_t: public std::map<int, nodetext_cache_t>
  {
  public:
    nodetext_cache_t *get(int node_id)
    {
      iterator it = find(node_id);
      if ( it == end() )
        return NULL;
      return &it->second;
    }
    nodetext_cache_t *add(const int node_id, const char *text, bgcolor_t bgcolor = DEFCOLOR)
    {
      return &(insert(std::make_pair(node_id, nodetext_cache_t(text, bgcolor))).first->second);
    }
  };

  class cmdid_map_t: public std::map<Py_ssize_t, py_graph_t *>
  {
  private:
    Py_ssize_t uid;
  public:

    cmdid_map_t()
    {
      // We start by one and keep zero for error id
      uid = 1;
    }

    void add(py_graph_t *pyg)
    {
      (*this)[uid] = pyg;
      ++uid;
    }

    const Py_ssize_t id() const
    {
      return uid;
    }

    void clear(py_graph_t *pyg)
    {
      iterator e = end();
      for (iterator it=begin();it!=end();)
      {
        if ( it->second == pyg )
        {
          iterator temp = it++;
          erase(temp);
        }
        else
          ++it;
      }
    }

    py_graph_t *get(Py_ssize_t id)
    {
      iterator it = find(id);
      return it == end() ? NULL : it->second;
    }
  };

  static cmdid_map_t cmdid_pyg;

  // TForm *form;
  bool refresh_needed;
  nodetext_cache_map_t node_cache;

  // instance callback
  int gr_callback(int code, va_list va);

  // static callback
  static int idaapi s_callback(void *obj, int code, va_list va)
  {
    PYW_GIL_GET;
    return ((py_graph_t *)obj)->gr_callback(code, va);
  }

  static bool idaapi s_menucb(void *ud)
  {
    PYW_GIL_GET;
    Py_ssize_t id = (Py_ssize_t)ud;
    py_graph_t *_this = cmdid_pyg.get(id);
    if ( _this != NULL )
      _this->on_command(id);

    return true;
  }

  void on_command(Py_ssize_t id)
  {
    // Check return value to OnRefresh() call
    PYW_GIL_CHECK_LOCKED_SCOPE();
    newref_t ret(PyObject_CallMethod(self.o, (char *)S_ON_COMMAND, "n", id));
  }

  // Refresh user-defined graph node number and edges
  // It calls Python method and expects that the user already filled
  // the nodes and edges. The nodes and edges are retrieved and passed to IDA
  void on_user_refresh(mutable_graph_t *g);

  // Retrieves the text for user-defined graph node
  // It expects either a string or a tuple (string, bgcolor)
  bool on_user_text(mutable_graph_t * /*g*/, int node, const char **str, bgcolor_t *bg_color);

  // Retrieves the hint for the user-defined graph
  // Calls Python and expects a string or None
  int on_user_hint(mutable_graph_t *, int mousenode, int /*mouseedge_src*/, int /*mouseedge_dst*/, char **hint);

  // graph is being destroyed
  void on_graph_destroyed(mutable_graph_t * /*g*/ = NULL)
  {
    refresh_needed = true;
    node_cache.clear();
  }

  // graph is being clicked
  int on_clicked(
        graph_viewer_t * /*view*/,
        selection_item_t * /*item1*/,
        graph_item_t *item2)
  {
    // in:  graph_viewer_t *view
    //      selection_item_t *current_item1
    //      graph_item_t *current_item2
    // out: 0-ok, 1-ignore click
    // this callback allows you to ignore some clicks.
    // it occurs too early, internal graph variables are not updated yet
    // current_item1, current_item2 point to the same thing
    // item2 has more information.
    // see also: kernwin.hpp, custom_viewer_click_t
    if ( item2->n == -1 )
      return 1;

    PYW_GIL_CHECK_LOCKED_SCOPE();
    newref_t result(
            PyObject_CallMethod(
                    self.o,
                    (char *)S_ON_CLICK,
                    "i",
                    item2->n));
    return result == NULL || !PyObject_IsTrue(result.o);
  }

  // a graph node has been double clicked
  int on_dblclicked(graph_viewer_t * /*view*/, selection_item_t *item)
  {
    // in:  graph_viewer_t *view
    //      selection_item_t *current_item
    // out: 0-ok, 1-ignore click
    //graph_viewer_t *v   = va_arg(va, graph_viewer_t *);
    //selection_item_t *s = va_arg(va, selection_item_t *);
    if ( item == NULL || !item->is_node )
      return 1;

    PYW_GIL_CHECK_LOCKED_SCOPE();
    newref_t result(
            PyObject_CallMethod(
                    self.o,
                    (char *)S_ON_DBL_CLICK,
                    "i",
                    item->node));
    return result == NULL || !PyObject_IsTrue(result.o);
  }

  // a graph viewer got focus
  void on_gotfocus(graph_viewer_t * /*view*/)
  {
    PYW_GIL_CHECK_LOCKED_SCOPE();
    newref_t result(
            PyObject_CallMethod(
                    self.o,
                    (char *)S_ON_ACTIVATE,
                    NULL));
  }

  // a graph viewer lost focus
  void on_lostfocus(graph_viewer_t * /*view*/)
  {
    PYW_GIL_CHECK_LOCKED_SCOPE();
    newref_t result(
            PyObject_CallMethod(
                    self.o,
                    (char *)S_ON_DEACTIVATE,
                    NULL));
  }

  // a new graph node became the current node
  int on_changed_current(graph_viewer_t * /*view*/, int curnode)
  {
    // in:  graph_viewer_t *view
    //      int curnode
    // out: 0-ok, 1-forbid to change the current node
    if ( curnode < 0 )
      return 0;

    PYW_GIL_CHECK_LOCKED_SCOPE();
    newref_t result(
            PyObject_CallMethod(
                    self.o,
                    (char *)S_ON_SELECT,
                    "i",
                    curnode));
    return !(result != NULL && PyObject_IsTrue(result.o));
  }

  // a group is being created
  int on_creating_group(mutable_graph_t *my_g, intset_t *my_nodes)
  {
    PYW_GIL_CHECK_LOCKED_SCOPE();
    printf("my_g: %p; my_nodes: %p\n", my_g, my_nodes);
    newref_t py_nodes(PyList_New(my_nodes->size()));
    int i;
    intset_t::const_iterator p;
    for ( i = 0, p=my_nodes->begin(); p != my_nodes->end(); ++p, ++i )
      PyList_SetItem(py_nodes.o, i, PyInt_FromLong(*p));
    newref_t py_result(
            PyObject_CallMethod(
                    self.o,
                    (char *)S_ON_CREATING_GROUP,
                    "O",
                    py_nodes.o));
    return (py_result == NULL || !PyInt_Check(py_result.o)) ? 1 : PyInt_AsLong(py_result.o);
  }

  // a group is being deleted
  int on_deleting_group(mutable_graph_t * /*g*/, int old_group)
  {
    PYW_GIL_CHECK_LOCKED_SCOPE();
    // TODO
    return 0;
  }

  // a group is being collapsed/uncollapsed
  int on_group_visibility(mutable_graph_t * /*g*/, int group, bool expand)
  {
    PYW_GIL_CHECK_LOCKED_SCOPE();
    // TODO
    return 0;
  }


  void show()
  {
    TForm *form;
    if ( lookup_info.find_by_py_view(&form, NULL, this) )
      open_tform(form, FORM_TAB|FORM_MENU|FORM_QWIDGET);
  }

  void jump_to_node(int nid)
  {
    viewer_center_on(view, nid);
    int x, y;

    // will return a place only when a node was previously selected
    place_t *old_pl = get_custom_viewer_place(view, false, &x, &y);
    if ( old_pl != NULL )
    {
      user_graph_place_t *new_pl = (user_graph_place_t *) old_pl->clone();
      new_pl->node = nid;
      jumpto(view, new_pl, x, y);
      delete new_pl;
    }
  }

  virtual void refresh()
  {
    refresh_needed = true;
    inherited::refresh();
  }

  int initialize(PyObject *self, const char *title)
  {
    PYW_GIL_CHECK_LOCKED_SCOPE();

    if ( !collect_pyobject_callbacks(self) )
      return -1;

    // Create form
    HWND hwnd = NULL;
    TForm *form = create_tform(title, &hwnd);
    if ( hwnd != NULL ) // Created new tform
    {
      // get a unique graph id
      netnode id;
      char grnode[MAXSTR];
      qsnprintf(grnode, sizeof(grnode), "$ pygraph %s", title);
      id.create(grnode);
      graph_viewer_t *pview = create_graph_viewer(form, id, s_callback, this, 0);
      open_tform(form, FORM_TAB | FORM_MENU | FORM_QWIDGET);
      if ( pview != NULL )
        viewer_fit_window(pview);
      bind(self, pview);
      refresh();
      // Link "form" and "py_graph"
      lookup_info.add(form, view, this);
    }
    else
    {
      show();
    }

    viewer_fit_window(view);
    return 0;
  }

  Py_ssize_t add_command(const char *title, const char *hotkey)
  {
    if ( !has_callback(GRCODE_HAVE_COMMAND) || view == NULL)
      return 0;
    Py_ssize_t cmd_id = cmdid_pyg.id();
    bool ok = viewer_add_menu_item(view, title, s_menucb, (void *)cmd_id, hotkey, 0);
    if ( !ok )
      return 0;
    cmdid_pyg.add(this);
    return cmd_id;
  }

public:
  py_graph_t()
  {
    // form = NULL;
    refresh_needed = true;
  }

  virtual ~py_graph_t()
  {
    // Remove all associated commands from the list
    cmdid_pyg.clear(this);
  }

  static void SelectNode(PyObject *self, int /*nid*/)
  {
    py_graph_t *_this = view_extract_this<py_graph_t>(self);
    if ( _this == NULL || !lookup_info.find_by_py_view(NULL, NULL, _this) )
      return;

    _this->jump_to_node(0);
  }

  static Py_ssize_t AddCommand(PyObject *self, const char *title, const char *hotkey)
  {
    py_graph_t *_this = view_extract_this<py_graph_t>(self);
    if ( _this == NULL || !lookup_info.find_by_py_view(NULL, NULL, _this) )
      return 0;

    return _this->add_command(title, hotkey);
  }

  static void Close(PyObject *self)
  {
    TForm *form;
    py_graph_t *_this = view_extract_this<py_graph_t>(self);
    if ( _this == NULL || !lookup_info.find_by_py_view(&form, NULL, _this) )
      return;
    close_tform(form, FORM_CLOSE_LATER);
  }

  static py_graph_t *Show(PyObject *self)
  {
    PYW_GIL_CHECK_LOCKED_SCOPE();

    py_graph_t *py_graph = view_extract_this<py_graph_t>(self);

    // New instance?
    if ( py_graph == NULL )
    {
      qstring title;
      if ( !PyW_GetStringAttr(self, S_M_TITLE, &title) )
        return NULL;

      // Form already created? try to get associated py_graph instance
      // so that we reuse it
      graph_viewer_t *found_view;
      TForm *form = find_tform(title.c_str());
      if ( form != NULL )
        lookup_info.find_by_form(&found_view, (py_customidamemo_t**) &py_graph, form);

      if ( py_graph == NULL )
      {
        py_graph = new py_graph_t();
      }
      else
      {
        // unbind so we are rebound
        py_graph->unbind();
        py_graph->refresh_needed = true;
      }
      if ( py_graph->initialize(self, title.c_str()) < 0 )
      {
        delete py_graph;
        py_graph = NULL;
      }
    }
    else
    {
      py_graph->show();
    }
    return py_graph;
  }
};

//-------------------------------------------------------------------------
void py_graph_t::collect_class_callbacks_ids(callbacks_ids_t *out)
{
  inherited::collect_class_callbacks_ids(out);
  out->add(S_ON_REFRESH, 0);
  out->add(S_ON_GETTEXT, 0);
  out->add(S_M_EDGES, -1);
  out->add(S_M_NODES, -1);
  out->add(S_ON_HINT, GRCODE_HAVE_USER_HINT);
  out->add(S_ON_CLICK, GRCODE_HAVE_CLICKED);
  out->add(S_ON_DBL_CLICK, GRCODE_HAVE_DBL_CLICKED);
  out->add(S_ON_COMMAND, GRCODE_HAVE_COMMAND);
  out->add(S_ON_SELECT, GRCODE_HAVE_CHANGED_CURRENT);
  out->add(S_ON_ACTIVATE, GRCODE_HAVE_GOTFOCUS);
  out->add(S_ON_DEACTIVATE, GRCODE_HAVE_LOSTFOCUS);
}

//-------------------------------------------------------------------------
void py_graph_t::on_user_refresh(mutable_graph_t *g)
{
  if ( !refresh_needed || self == NULL /* Happens at creation-time */ )
    return;

  // Check return value to OnRefresh() call
  PYW_GIL_CHECK_LOCKED_SCOPE();
  newref_t ret(PyObject_CallMethod(self.o, (char *)S_ON_REFRESH, NULL));
  if ( ret != NULL && PyObject_IsTrue(ret.o) )
  {
    // Refer to the nodes
    ref_t nodes(PyW_TryGetAttrString(self.o, S_M_NODES));
    if ( ret != NULL && PyList_Check(nodes.o) )
    {
      // Refer to the edges
      ref_t edges(PyW_TryGetAttrString(self.o, S_M_EDGES));
      if ( ret != NULL && PyList_Check(edges.o) )
      {
        // Resize the nodes
        int max_nodes = abs(int(PyList_Size(nodes.o)));
        g->clear();
        g->resize(max_nodes);

        // Mark that we refreshed already
        refresh_needed = false;

        // Clear cached nodes
        node_cache.clear();

        // Get the edges
        for ( int i=(int)PyList_Size(edges.o)-1; i>=0; i-- )
        {
          // Each list item is a sequence (id1, id2)
          borref_t item(PyList_GetItem(edges.o, i));
          if ( !PySequence_Check(item.o) )
            continue;

          // Get and validate each of the two elements in the sequence
          int edge_ids[2];
          int j;
          for ( j=0; j<qnumber(edge_ids); j++ )
          {
            newref_t id(PySequence_GetItem(item.o, j));
            if ( id == NULL || !PyInt_Check(id.o) )
              break;
            int v = int(PyInt_AS_LONG(id.o));
            if ( v > max_nodes )
              break;
            edge_ids[j] = v;
          }

          // Incomplete?
          if ( j != qnumber(edge_ids) )
            break;

          // Add the edge
          g->add_edge(edge_ids[0], edge_ids[1], NULL);
        }
      }
    }
  }
}

//-------------------------------------------------------------------------
bool py_graph_t::on_user_text(mutable_graph_t * /*g*/, int node, const char **str, bgcolor_t *bg_color)
{
  // If already cached then return the value
  nodetext_cache_t *c = node_cache.get(node);
  if ( c != NULL )
  {
    *str = c->text.c_str();
    if ( bg_color != NULL )
      *bg_color = c->bgcolor;
    return true;
  }

  // Not cached, call Python
  PYW_GIL_CHECK_LOCKED_SCOPE();
  newref_t result(PyObject_CallMethod(self.o, (char *)S_ON_GETTEXT, "i", node));
  if ( result == NULL )
    return false;

  bgcolor_t cl = bg_color == NULL ? DEFCOLOR : *bg_color;
  const char *s;

  // User returned a string?
  if ( PyString_Check(result.o) )
  {
    s = PyString_AsString(result.o);
    if ( s == NULL )
      s = "";
    c = node_cache.add(node, s, cl);
  }
  // User returned a sequence of text and bgcolor
  else if ( PySequence_Check(result.o) && PySequence_Size(result.o) == 2 )
  {
    newref_t py_str(PySequence_GetItem(result.o, 0));
    newref_t py_color(PySequence_GetItem(result.o, 1));

    if ( py_str == NULL || !PyString_Check(py_str.o) || (s = PyString_AsString(py_str.o)) == NULL )
      s = "";
    if ( py_color != NULL && PyNumber_Check(py_color.o) )
      cl = bgcolor_t(PyLong_AsUnsignedLong(py_color.o));

    c = node_cache.add(node, s, cl);
  }

  *str = c->text.c_str();
  if ( bg_color != NULL )
    *bg_color = c->bgcolor;

  return true;
}

//-------------------------------------------------------------------------
int py_graph_t::on_user_hint(mutable_graph_t *, int mousenode, int /*mouseedge_src*/, int /*mouseedge_dst*/, char **hint)
{
  // 'hint' must be allocated by qalloc() or qstrdup()
  // out: 0-use default hint, 1-use proposed hint

  // We dispatch hints over nodes only
  if ( mousenode == -1 )
    return 0;

  PYW_GIL_CHECK_LOCKED_SCOPE();
  newref_t result(PyObject_CallMethod(self.o, (char *)S_ON_HINT, "i", mousenode));
  bool ok = result != NULL && PyString_Check(result.o);
  if ( ok )
    *hint = qstrdup(PyString_AsString(result.o));
  return ok; // use our hint
}


//-------------------------------------------------------------------------
int py_graph_t::gr_callback(int code, va_list va)
{
  int ret;
  switch ( code )
  {
    //
    case grcode_user_text:
      {
        mutable_graph_t *g  = va_arg(va, mutable_graph_t *);
        int node            = va_arg(va, int);
        const char **result = va_arg(va, const char **);
        bgcolor_t *bgcolor  = va_arg(va, bgcolor_t *);
        ret = on_user_text(g, node, result, bgcolor);
        break;
      }
      //
    case grcode_destroyed:
      on_graph_destroyed(va_arg(va, mutable_graph_t *));
      ret = 0;
      break;

      //
    case grcode_clicked:
      if ( has_callback(GRCODE_HAVE_CLICKED) )
      {
        graph_viewer_t *view     = va_arg(va, graph_viewer_t *);
        selection_item_t *item = va_arg(va, selection_item_t *);
        graph_item_t    *gitem = va_arg(va, graph_item_t *);
        ret = on_clicked(view, item, gitem);
      }
      else
      {
        // Ignore the click
        ret = 1;
      }
      break;
      //
    case grcode_dblclicked:
      if ( has_callback(GRCODE_HAVE_DBL_CLICKED) )
      {
        graph_viewer_t *view     = va_arg(va, graph_viewer_t *);
        selection_item_t *item = va_arg(va, selection_item_t *);
        ret = on_dblclicked(view, item);
      }
      else
        ret = 1; // ignore
      break;
      //
    case grcode_gotfocus:
      if ( has_callback(GRCODE_HAVE_GOTFOCUS) )
        on_gotfocus(va_arg(va, graph_viewer_t *));

      ret = 0;
      break;
      //
    case grcode_lostfocus:
      if ( has_callback(GRCODE_HAVE_LOSTFOCUS) )
        on_lostfocus(va_arg(va, graph_viewer_t *));

      ret = 0;
      break;
      //
    case grcode_user_refresh:
      on_user_refresh(va_arg(va, mutable_graph_t *));

      ret = 1;
      break;
      //
    case grcode_user_hint:
      if ( has_callback(GRCODE_HAVE_USER_HINT) )
      {
        mutable_graph_t *g = va_arg(va, mutable_graph_t *);
        int mousenode      = va_arg(va, int);
        int mouseedge_src  = va_arg(va, int);
        int mouseedge_dest = va_arg(va, int);
        char **hint        = va_arg(va, char **);
        ret = on_user_hint(g, mousenode, mouseedge_src, mouseedge_dest, hint);
      }
      else
      {
        ret = 0;
      }
      break;
      //
    case grcode_changed_current:
      if ( has_callback(GRCODE_HAVE_CHANGED_CURRENT) )
      {
        graph_viewer_t *view = va_arg(va, graph_viewer_t *);
        int cur_node = va_arg(va, int);
        ret = on_changed_current(view, cur_node);
      }
      else
        ret = 0; // allow selection change
      break;
      //
    case grcode_creating_group:      // a group is being created
      {
        mutable_graph_t *g = va_arg(va, mutable_graph_t*);
        intset_t *nodes = va_arg(va, intset_t*);
        ret = on_creating_group(g, nodes);
      }
      break;
      //
    case grcode_deleting_group:      // a group is being deleted
      {
        mutable_graph_t *g = va_arg(va, mutable_graph_t*);
        int old_group = va_arg(va, int);
        ret = on_deleting_group(g, old_group);
      }
      break;
      //
    case grcode_group_visibility:    // a group is being collapsed/uncollapsed
      {
        mutable_graph_t *g = va_arg(va, mutable_graph_t*);
        int group = va_arg(va, int);
        bool expand = bool(va_arg(va, int));
        ret = on_group_visibility(g, group, expand);
      }
      break;
      //
    default:
      ret = 0;
      break;
  }
  //grcode_changed_graph,       // new graph has been set
  //grcode_user_size,           // calculate node size for user-defined graph
  //grcode_user_title,          // render node title of a user-defined graph
  //grcode_user_draw,           // render node of a user-defined graph
  return ret;
}

//-------------------------------------------------------------------------
py_graph_t::cmdid_map_t py_graph_t::cmdid_pyg;

bool pyg_show(PyObject *self)
{
  return py_graph_t::Show(self) != NULL;
}

void pyg_close(PyObject *self)
{
  py_graph_t::Close(self);
}

PyObject *pyg_add_command(PyObject *self, const char *title, const char *hotkey)
{
  PYW_GIL_CHECK_LOCKED_SCOPE();
  return Py_BuildValue("n", py_graph_t::AddCommand(self, title, hotkey));
}

void pyg_select_node(PyObject *self, int nid)
{
  py_graph_t::SelectNode(self, nid);
}
//</code(py_graph)>
%}

%inline %{
//<inline(py_graph)>
void pyg_close(PyObject *self);
PyObject *pyg_add_command(PyObject *self, const char *title, const char *hotkey);
void pyg_select_node(PyObject *self, int nid);
bool pyg_show(PyObject *self);
//</inline(py_graph)>
%}

%pythoncode %{
#<pycode(py_graph)>
class GraphViewer(CustomIDAMemo):
    """This class wraps the user graphing facility provided by the graph.hpp file"""
    def __init__(self, title, close_open = False):
        """
        Constructs the GraphView object.
        Please do not remove or rename the private fields

        @param title: The title of the graph window
        @param close_open: Should it attempt to close an existing graph (with same title) before creating this graph?
        """
        self._title = title
        self._nodes = []
        self._edges = []
        self._close_open = close_open

    def AddNode(self, obj):
        """Creates a node associated with the given object and returns the node id"""
        id = len(self._nodes)
        self._nodes.append(obj)
        return id

    def AddEdge(self, src_node, dest_node):
        """Creates an edge between two given node ids"""
        self._edges.append( (src_node, dest_node) )

    def Clear(self):
        """Clears all the nodes and edges"""
        self._nodes = []
        self._edges = []


    def __iter__(self):
        return (self._nodes[index] for index in xrange(0, len(self._nodes)))


    def __getitem__(self, idx):
        """Returns a reference to the object associated with this node id"""
        if idx >= len(self._nodes):
            raise KeyError
        else:
            return self._nodes[idx]

    def Count(self):
        """Returns the node count"""
        return len(self._nodes)

    def Close(self):
        """
        Closes the graph.
        It is possible to call Show() again (which will recreate the graph)
        """
        _idaapi.pyg_close(self)

    def Show(self):
        """
        Shows an existing graph or creates a new one

        @return: Boolean
        """
        if self._close_open:
            frm = _idaapi.find_tform(self._title)
            if frm:
                _idaapi.close_tform(frm, 0)
        return _idaapi.pyg_show(self)

    def Select(self, node_id):
        """Selects a node on the graph"""
        _idaapi.pyg_select_node(self, node_id)

    def AddCommand(self, title, hotkey):
        """
        Adds a menu command to the graph. Call this command after the graph is shown (with Show()).
        Once a command is added, a command id is returned. The commands are handled inside the OnCommand() handler

        @return: 0 on failure or the command id
        """
        return _idaapi.pyg_add_command(self, title, hotkey)

    def OnRefresh(self):
        """
        Event called when the graph is refreshed or first created.
        From this event you are supposed to create nodes and edges.
        This callback is mandatory.

        @note: ***It is important to clear previous nodes before adding nodes.***
        @return: Returning True tells the graph viewer to use the items. Otherwise old items will be used.
        """
        self.Clear()

        return True
#<pydoc>
#    def OnGetText(self, node_id):
#        """
#        Triggered when the graph viewer wants the text and color for a given node.
#        This callback is triggered one time for a given node (the value will be cached and used later without calling Python).
#        When you call refresh then again this callback will be called for each node.
#
#        This callback is mandatory.
#
#        @return: Return a string to describe the node text or return a tuple (node_text, node_color) to describe both text and color
#        """
#        return str(self[node_id])
#
#    def OnActivate(self):
#        """
#        Triggered when the graph window gets the focus
#        @return: None
#        """
#        print "Activated...."
#
#    def OnDeactivate(self):
#        """Triggered when the graph window loses the focus
#        @return: None
#        """
#        print "Deactivated...."
#
#    def OnSelect(self, node_id):
#        """
#        Triggered when a node is being selected
#        @return: Return True to allow the node to be selected or False to disallow node selection change
#        """
#        # allow selection change
#        return True
#
#    def OnHint(self, node_id):
#        """
#        Triggered when the graph viewer wants to retrieve hint text associated with a given node
#
#        @return: None if no hint is avail or a string designating the hint
#        """
#        return "hint for " + str(node_id)
#
#    def OnClose(self):
#        """Triggered when the graph viewer window is being closed
#        @return: None
#        """
#        print "Closing......."
#
#    def OnClick(self, node_id):
#        """
#        Triggered when a node is clicked
#        @return: False to ignore the click and True otherwise
#        """
#        print "clicked on", self[node_id]
#        return True
#
#    def OnDblClick(self, node_id):
#        """
#        Triggerd when a node is double-clicked.
#        @return: False to ignore the click and True otherwise
#        """
#        print "dblclicked on", self[node_id]
#        return True
#
#    def OnCommand(self, cmd_id):
#        """
#        Triggered when a menu command is selected through the menu or its hotkey
#        @return: None
#        """
#        print "command:", cmd_id
#</pydoc>
#</pycode(py_graph)>
%}

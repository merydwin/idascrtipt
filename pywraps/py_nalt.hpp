#ifndef __PY_IDA_NALT__
#define __PY_IDA_NALT__

//<code(py_nalt)>

//-------------------------------------------------------------------------
// callback for enumerating imports
// ea:   import address
// name: import name (NULL if imported by ordinal)
// ord:  import ordinal (0 for imports by name)
// param: user parameter passed to enum_import_names()
// return: 1-ok, 0-stop enumeration
static int idaapi py_import_enum_cb(
  ea_t ea,
  const char *name,
  uval_t ord,
  void *param)
{
  // If no name, try to get the name associated with the 'ea'. It may be coming from IDS
  char name_buf[MAXSTR];
  if ( name == NULL )
    name = get_true_name(BADADDR, ea, name_buf, sizeof(name_buf));

  PYW_GIL_CHECK_LOCKED_SCOPE();
  ref_t py_name;
  if ( name == NULL )
    py_name = borref_t(Py_None);
  else
    py_name = newref_t(PyString_FromString(name));

  newref_t py_ord(Py_BuildValue(PY_FMT64, pyul_t(ord)));
  newref_t py_ea(Py_BuildValue(PY_FMT64, pyul_t(ea)));
  newref_t py_result(
          PyObject_CallFunctionObjArgs(
                  (PyObject *)param,
                  py_ea.o,
                  py_name.o,
                  py_ord.o,
                  NULL));
  return py_result != NULL && PyObject_IsTrue(py_result.o) ? 1 : 0;
}

//-------------------------------------------------------------------------
switch_info_ex_t *switch_info_ex_t_get_clink(PyObject *self)
{
  PYW_GIL_CHECK_LOCKED_SCOPE();
  if ( !PyObject_HasAttrString(self, S_CLINK_NAME) )
    return NULL;

  switch_info_ex_t *r;
  newref_t attr(PyObject_GetAttrString(self, S_CLINK_NAME));
  return PyCObject_Check(attr.o) ? ((switch_info_ex_t *) PyCObject_AsVoidPtr(attr.o)) : NULL;
}
//</code(py_nalt)>

//<inline(py_nalt)>

//-------------------------------------------------------------------------
/*
#<pydoc>
def get_import_module_name(path, fname, callback):
    """
    Returns the name of an imported module given its index
    @return: None or the module name
    """
    pass
#</pydoc>
*/
static PyObject *py_get_import_module_name(int mod_index)
{
  PYW_GIL_CHECK_LOCKED_SCOPE();
  char buf[MAXSTR];
  if ( !get_import_module_name(mod_index, buf, sizeof(buf)) )
    Py_RETURN_NONE;

  return PyString_FromString(buf);
}

//-------------------------------------------------------------------------
/*
#<pydoc>
def get_switch_info_ex(ea):
    """
    Returns the a switch_info_ex_t structure containing the information about the switch.
    Please refer to the SDK sample 'uiswitch'
    @return: None or switch_info_ex_t instance
    """
    pass
#</pydoc>
*/
PyObject *py_get_switch_info_ex(ea_t ea)
{
  switch_info_ex_t *ex = new switch_info_ex_t();
  ref_t py_obj;
  PYW_GIL_CHECK_LOCKED_SCOPE();
  if ( ::get_switch_info_ex(ea, ex, sizeof(switch_info_ex_t)) <= 0
    || (py_obj = create_idaapi_linked_class_instance(S_PY_SWIEX_CLSNAME, ex)) == NULL )
  {
    delete ex;
    Py_RETURN_NONE;
  }
  py_obj.incref();
  return py_obj.o;
}

//-------------------------------------------------------------------------
/*
#<pydoc>
def create_switch_xrefs(insn_ea, si):
    """
    This function creates xrefs from the indirect jump.

    Usually there is no need to call this function directly because the kernel
    will call it for switch tables

    Note: Custom switch information are not supported yet.

    @param insn_ea: address of the 'indirect jump' instruction
    @param si: switch information

    @return: Boolean
    """
    pass
#</pydoc>
*/
idaman bool ida_export py_create_switch_xrefs(
  ea_t insn_ea,
  PyObject *py_swi)
{
  switch_info_ex_t *swi = switch_info_ex_t_get_clink(py_swi);
  if ( swi == NULL )
    return false;

  create_switch_xrefs(insn_ea, swi);
  return true;
}


//-------------------------------------------------------------------------
/*
#<pydoc>
def create_switch_table(insn_ea, si):
    """
    Create switch table from the switch information

    @param insn_ea: address of the 'indirect jump' instruction
    @param si: switch information

    @return: Boolean
    """
    pass
#</pydoc>
*/
idaman bool ida_export py_create_switch_table(
  ea_t insn_ea,
  PyObject *py_swi)
{
  switch_info_ex_t *swi = switch_info_ex_t_get_clink(py_swi);
  if ( swi == NULL )
    return false;

  create_switch_table(insn_ea, swi);
  return true;
}

//-------------------------------------------------------------------------
/*
#<pydoc>
def set_switch_info_ex(ea, switch_info_ex):
    """
    Saves the switch information in the database
    Please refer to the SDK sample 'uiswitch'
    @return: Boolean
    """
    pass
#</pydoc>
*/
bool py_set_switch_info_ex(ea_t ea, PyObject *py_swi)
{
  switch_info_ex_t *swi = switch_info_ex_t_get_clink(py_swi);
  if ( swi == NULL )
    return false;

  set_switch_info_ex(ea, swi);
  return true;
}

//-------------------------------------------------------------------------
/*
#<pydoc>
def del_switch_info_ex(ea):
    """
    Deletes stored switch information
    """
    pass
#</pydoc>
*/
void py_del_switch_info_ex(ea_t ea)
{
  del_switch_info_ex(ea);
}

//-------------------------------------------------------------------------
/*
#<pydoc>
def enum_import_names(mod_index, callback):
    """
    Enumerate imports from a specific module.
    Please refer to ex_imports.py example.

    @param mod_index: The module index
    @param callback: A callable object that will be invoked with an ea, name (could be None) and ordinal.
    @return: 1-finished ok, -1 on error, otherwise callback return value (<=0)
    """
    pass
#</pydoc>
*/
static int py_enum_import_names(int mod_index, PyObject *py_cb)
{
  PYW_GIL_CHECK_LOCKED_SCOPE();
  if ( !PyCallable_Check(py_cb) )
    return -1;
  return enum_import_names(mod_index, py_import_enum_cb, py_cb);
}

//-------------------------------------------------------------------------
static PyObject *switch_info_ex_t_create()
{
  switch_info_ex_t *inst = new switch_info_ex_t();
  PYW_GIL_CHECK_LOCKED_SCOPE();
  return PyCObject_FromVoidPtr(inst, NULL);
}

//---------------------------------------------------------------------------
static bool switch_info_ex_t_destroy(PyObject *py_obj)
{
  PYW_GIL_CHECK_LOCKED_SCOPE();
  if ( !PyCObject_Check(py_obj) )
    return false;
  switch_info_ex_t *inst = (switch_info_ex_t *) PyCObject_AsVoidPtr(py_obj);
  delete inst;
  return true;
}

static bool switch_info_ex_t_assign(PyObject *self, PyObject *other)
{
  switch_info_ex_t *lhs = switch_info_ex_t_get_clink(self);
  switch_info_ex_t *rhs = switch_info_ex_t_get_clink(other);
  if (lhs == NULL || rhs == NULL)
    return false;

  *lhs = *rhs;
  return true;
}

//-------------------------------------------------------------------------
// Auto generated - begin
//

static PyObject *switch_info_ex_t_get_regdtyp(PyObject *self)
{
  switch_info_ex_t *link = switch_info_ex_t_get_clink(self);
  PYW_GIL_CHECK_LOCKED_SCOPE();
  if ( link == NULL )
    Py_RETURN_NONE;
  return Py_BuildValue("b", (char)link->regdtyp);
}
static void switch_info_ex_t_set_regdtyp(PyObject *self, PyObject *value)
{
  switch_info_ex_t *link = switch_info_ex_t_get_clink(self);
  if ( link == NULL )
    return;
  PYW_GIL_CHECK_LOCKED_SCOPE();
  link->regdtyp = (char)PyInt_AsLong(value);
}

static PyObject *switch_info_ex_t_get_flags2(PyObject *self)
{
  switch_info_ex_t *link = switch_info_ex_t_get_clink(self);
  PYW_GIL_CHECK_LOCKED_SCOPE();
  if ( link == NULL )
    Py_RETURN_NONE;
  return Py_BuildValue("i", link->flags2);
}
static void switch_info_ex_t_set_flags2(PyObject *self, PyObject *value)
{
  switch_info_ex_t *link = switch_info_ex_t_get_clink(self);
  if ( link == NULL )
    return;
  PYW_GIL_CHECK_LOCKED_SCOPE();
  link->flags2 = (int)PyInt_AsLong(value);
}

static PyObject *switch_info_ex_t_get_jcases(PyObject *self)
{
  switch_info_ex_t *link = switch_info_ex_t_get_clink(self);
  PYW_GIL_CHECK_LOCKED_SCOPE();
  if ( link == NULL )
    Py_RETURN_NONE;
  return Py_BuildValue("i", link->jcases);
}
static void switch_info_ex_t_set_jcases(PyObject *self, PyObject *value)
{
  switch_info_ex_t *link = switch_info_ex_t_get_clink(self);
  if ( link == NULL )
    return;
  PYW_GIL_CHECK_LOCKED_SCOPE();
  link->jcases = (int)PyInt_AsLong(value);
}

static PyObject *switch_info_ex_t_get_regnum(PyObject *self)
{
  switch_info_ex_t *link = switch_info_ex_t_get_clink(self);
  PYW_GIL_CHECK_LOCKED_SCOPE();
  if ( link == NULL )
    Py_RETURN_NONE;
  return Py_BuildValue("i", (int)link->regnum);
}
static void switch_info_ex_t_set_regnum(PyObject *self, PyObject *value)
{
  switch_info_ex_t *link = switch_info_ex_t_get_clink(self);
  if ( link == NULL )
    return;
  PYW_GIL_CHECK_LOCKED_SCOPE();
  link->regnum = (int)PyInt_AsLong(value);
}

static PyObject *switch_info_ex_t_get_flags(PyObject *self)
{
  switch_info_ex_t *link = switch_info_ex_t_get_clink(self);
  PYW_GIL_CHECK_LOCKED_SCOPE();
  if ( link == NULL )
    Py_RETURN_NONE;
  return Py_BuildValue("H", (ushort)link->flags);
}
static void switch_info_ex_t_set_flags(PyObject *self, PyObject *value)
{
  switch_info_ex_t *link = switch_info_ex_t_get_clink(self);
  if ( link == NULL )
    return;
  PYW_GIL_CHECK_LOCKED_SCOPE();
  link->flags = (uint16)PyInt_AsLong(value);
}

static PyObject *switch_info_ex_t_get_ncases(PyObject *self)
{
  switch_info_ex_t *link = switch_info_ex_t_get_clink(self);
  PYW_GIL_CHECK_LOCKED_SCOPE();
  if ( link == NULL )
    Py_RETURN_NONE;
  return Py_BuildValue("H", (uint16)link->ncases);
}
static void switch_info_ex_t_set_ncases(PyObject *self, PyObject *value)
{
  switch_info_ex_t *link = switch_info_ex_t_get_clink(self);
  if ( link == NULL )
    return;
  PYW_GIL_CHECK_LOCKED_SCOPE();
  link->ncases = (ushort)PyInt_AsLong(value);
}

static PyObject *switch_info_ex_t_get_defjump(PyObject *self)
{
  switch_info_ex_t *link = switch_info_ex_t_get_clink(self);
  PYW_GIL_CHECK_LOCKED_SCOPE();
  if ( link == NULL )
    Py_RETURN_NONE;
  return Py_BuildValue(PY_FMT64, (pyul_t)link->defjump);
}
static void switch_info_ex_t_set_defjump(PyObject *self, PyObject *value)
{
  switch_info_ex_t *link = switch_info_ex_t_get_clink(self);
  if ( link == NULL )
    return;
  PYW_GIL_CHECK_LOCKED_SCOPE();
  uint64 v(0); PyW_GetNumber(value, &v);
  link->defjump = (pyul_t)v;
}

static PyObject *switch_info_ex_t_get_jumps(PyObject *self)
{
  switch_info_ex_t *link = switch_info_ex_t_get_clink(self);
  if ( link == NULL )
    Py_RETURN_NONE;
  return Py_BuildValue(PY_FMT64, (pyul_t)link->jumps);
}
static void switch_info_ex_t_set_jumps(PyObject *self, PyObject *value)
{
  switch_info_ex_t *link = switch_info_ex_t_get_clink(self);
  if ( link == NULL )
    return;
  PYW_GIL_CHECK_LOCKED_SCOPE();
  uint64 v(0); PyW_GetNumber(value, &v);
  link->jumps = (pyul_t)v;
}

static PyObject *switch_info_ex_t_get_elbase(PyObject *self)
{
  switch_info_ex_t *link = switch_info_ex_t_get_clink(self);
  PYW_GIL_CHECK_LOCKED_SCOPE();
  if ( link == NULL )
    Py_RETURN_NONE;
  return Py_BuildValue(PY_FMT64, (pyul_t)link->elbase);
}
static void switch_info_ex_t_set_elbase(PyObject *self, PyObject *value)
{
  switch_info_ex_t *link = switch_info_ex_t_get_clink(self);
  if ( link == NULL )
    return;
  uint64 v(0);
  PYW_GIL_CHECK_LOCKED_SCOPE();
  PyW_GetNumber(value, &v);
  link->elbase = (pyul_t)v;
}

static PyObject *switch_info_ex_t_get_startea(PyObject *self)
{
  switch_info_ex_t *link = switch_info_ex_t_get_clink(self);
  PYW_GIL_CHECK_LOCKED_SCOPE();
  if ( link == NULL )
    Py_RETURN_NONE;
  return Py_BuildValue(PY_FMT64, (pyul_t)link->startea);
}
static void switch_info_ex_t_set_startea(PyObject *self, PyObject *value)
{
  switch_info_ex_t *link = switch_info_ex_t_get_clink(self);
  if ( link == NULL )
    return;
  uint64 v(0);
  PYW_GIL_CHECK_LOCKED_SCOPE();
  PyW_GetNumber(value, &v);
  link->startea = (pyul_t)v;
}

static PyObject *switch_info_ex_t_get_custom(PyObject *self)
{
  switch_info_ex_t *link = switch_info_ex_t_get_clink(self);
  PYW_GIL_CHECK_LOCKED_SCOPE();
  if ( link == NULL )
    Py_RETURN_NONE;
  return Py_BuildValue(PY_FMT64, (pyul_t)link->custom);
}
static void switch_info_ex_t_set_custom(PyObject *self, PyObject *value)
{
  switch_info_ex_t *link = switch_info_ex_t_get_clink(self);
  if ( link == NULL )
    return;
  uint64 v(0);
  PYW_GIL_CHECK_LOCKED_SCOPE();
  PyW_GetNumber(value, &v);
  link->custom = (pyul_t)v;
}

static PyObject *switch_info_ex_t_get_ind_lowcase(PyObject *self)
{
  switch_info_ex_t *link = switch_info_ex_t_get_clink(self);
  PYW_GIL_CHECK_LOCKED_SCOPE();
  if ( link == NULL )
    Py_RETURN_NONE;
  return Py_BuildValue(PY_FMT64, (pyul_t)link->ind_lowcase);
}
static void switch_info_ex_t_set_ind_lowcase(PyObject *self, PyObject *value)
{
  switch_info_ex_t *link = switch_info_ex_t_get_clink(self);
  if ( link == NULL )
    return;
  uint64 v(0);
  PYW_GIL_CHECK_LOCKED_SCOPE();
  PyW_GetNumber(value, &v);
  link->ind_lowcase = (pyul_t)v;
}

static PyObject *switch_info_ex_t_get_values_lowcase(PyObject *self)
{
  switch_info_ex_t *link = switch_info_ex_t_get_clink(self);
  PYW_GIL_CHECK_LOCKED_SCOPE();
  if ( link == NULL )
    Py_RETURN_NONE;
  return Py_BuildValue(PY_FMT64, (pyul_t)link->values);
}
static void switch_info_ex_t_set_values_lowcase(PyObject *self, PyObject *value)
{
  switch_info_ex_t *link = switch_info_ex_t_get_clink(self);
  if ( link == NULL )
    return;
  uint64 v(0);
  PYW_GIL_CHECK_LOCKED_SCOPE();
  PyW_GetNumber(value, &v);
  link->values = (pyul_t)v;
}

//
// Auto generated - end
//
//-------------------------------------------------------------------------
//</inline(py_nalt)>

#endif

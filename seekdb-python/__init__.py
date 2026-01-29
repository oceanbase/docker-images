"""
OceanBase seekdb Python Embed

OceanBase seekdb Python Embed provides Python bindings for OceanBase seekdb, a high-performance embedded database engine.
This package supplies the lightweight interface layer for Python applications, making it easy to interact with seekdb
databases and execute SQL from Python code.
"""

import sys
import importlib.util
import importlib.metadata

def _package_name():
    return "pylibseekdb"

try:
  __version__ = importlib.metadata.version(_package_name())
except importlib.metadata.PackageNotFoundError:
  __version__ = "0.0.1.dev1"

__author__ = "OceanBase"

_LIB_FILE_NAME = "libseekdb_python"


def _initialize_module():
    try:
        seekdb_module = _load_oblite_module()
        attributes = []
        for attr_name in dir(seekdb_module):
            if not attr_name.startswith('_'):
                setattr(sys.modules[__name__], attr_name, getattr(seekdb_module, attr_name))
                attributes.append(attr_name)
    except Exception as e:
        print(f"Warning: Failed to import seekdb module: {e}")
        attributes = []
    return attributes

def _load_oblite_module():
    """Load the oblite module"""

    try:
        # Import the module
        # Attempt to find the pylibseekdb module path and add it to sys.path
        spec = importlib.util.find_spec(_package_name())
        if spec and spec.submodule_search_locations:
            module_path = list(spec.submodule_search_locations)[0]
            if module_path not in sys.path:
                sys.path.insert(0, module_path)

        import libseekdb_python
        return libseekdb_python
    except ImportError as e:
        raise ImportError(f"Failed to import {_LIB_FILE_NAME} module: {e}")

__all__ = ['__version__']
__all__.extend(_initialize_module())

#!/usr/bin/env python3
"""
Setup script for seekdb package
"""

import os
import sys
import subprocess
import shutil
from pathlib import Path
from setuptools import setup, find_packages, Extension
from setuptools.command.build_py import build_py
from setuptools.command.build_ext import build_ext
from wheel.bdist_wheel import bdist_wheel

# Get the current directory
current_dir = Path(__file__).parent

def get_version():
    """Get version from the seekdb module"""
    return os.environ.get('PACKAGE_VERSION', '0.0.1.dev1')

def get_description():
    """Get description from the seekdb module"""
    return "An AI-Native Search Database. Unifies vector, text, structured and semi-structured data in a single engine, enabling hybrid search and in-database AI workflows."

def get_long_description():
    """Get long description from README"""
    readme_file = current_dir / "README.md"
    if readme_file.exists():
        return readme_file.read_text(encoding='utf-8')
    return get_description()

def __library_name():
    return "libseekdb_python"

def __package_name():
    return "pylibseekdb"

def get_seekdb_source_dir():
    """Get the seekdb source directory"""
    return current_dir / "seekdb-source"

def get_project_root():
    """Get the project root directory"""
    # Current file is at package/wheel/core/setup.py
    # Project root is 3 levels up
    root = current_dir.parent.parent.parent
    return root.resolve()

def get_python_version():
    """Get Python version as X.Y"""
    return f"{sys.version_info.major}.{sys.version_info.minor}"

def get_python_home():
    """Get Python home directory"""
    python_home = os.environ.get('PYTHON_HOME', '')
    if python_home:
        return python_home
    # Try to infer from sys.executable
    return str(Path(sys.executable).parent.parent)

def clone_repo(source_url: str = None, target_dir: Path = None, git_tag: str = None, delete_if_exists: bool = False):
    """
    Clone the seekdb repository
    Args:
        git_tag: git branch, tag or commit id, if not provided, will clone the latest commit
    """
    if source_url is None:
        source_url = "https://github.com/oceanbase/seekdb.git"
    if target_dir is None:
        target_dir = get_seekdb_source_dir()

    if target_dir.exists() and (target_dir / ".git").exists():
        if delete_if_exists:
            shutil.rmtree(target_dir)
        else:
            return target_dir

    try:
        print(f"Cloning repository from {source_url} to {target_dir} with tag {git_tag}")
        subprocess.run(f"""mkdir -p {target_dir} \
                && cd {target_dir} \
                && git init \
                && git remote add origin {source_url} \
                && git fetch --progress --depth=1 origin {git_tag} \
                && git checkout FETCH_HEAD
                """,
                shell=True,
                check=True,
                capture_output=True,
                universal_newlines=True,
                text=True)
    except subprocess.CalledProcessError as e:
        print(e.stdout)
        print(e.stderr)
        raise Exception(f"Failed to clone repository: {e}")
    except Exception as e:
        raise Exception(f"Failed to clone repository: {e}")
    return target_dir

def install_dependencies() -> None:
    """Install dependencies for the library build"""
    print("Installing dependencies...")
    command = "yum install -y git wget rpm* cpio make glibc-devel glibc-headers binutils m4 libtool libaio ccache"
    result = subprocess.run(command, shell=True, check=False, capture_output=True, universal_newlines=True)
    if result.returncode != 0:
        print(result.stdout)
        print(result.stderr)
        raise Exception(f"Failed to install dependencies: {result.returncode}")


def build_library():
    """Build the libseekdb_python library"""
    seekdb_source_dir = get_seekdb_source_dir()
    build_type = os.environ.get('BUILD_TYPE', 'release')
    python_version = get_python_version()
    python_home = get_python_home()

    build_dir = seekdb_source_dir / f"build_{build_type}"
    library_path = build_dir / "src" / "observer" / "embed" / f"{__library_name()}.so"

    # Check if library already exists and rebuild flag is not set
    rebuild = os.environ.get('REBUILD', '1')
    if rebuild == '0' and library_path.exists():
        print(f"Library already exists at {library_path}, skipping build")
        return library_path

    print(f"Building library in {seekdb_source_dir}...")
    print(f"  Build type: {build_type}")
    print(f"  Python version: {python_version}")
    print(f"  Python home: {python_home}")

    # Build command
    build_cmd = [
        str(seekdb_source_dir / "build.sh"),
        build_type,
        "--init",
        "-DOB_USE_CCACHE=ON",
        "-DBUILD_EMBED_MODE=ON",
        f"-DPYTHON_VERSION={python_version}",
        f"-DCMAKE_PREFIX_PATH={python_home}",
        "--make"
    ]

    # Run build
    print(f"Building library with command: {build_cmd}")
    result = subprocess.run(
        build_cmd,
        cwd=str(seekdb_source_dir),
        check=True,
        capture_output=False
    )
    if result.returncode != 0:
        print(result.stdout)
        print(result.stderr)
        raise Exception(f"Failed to build library: {result.returncode}")

    if not library_path.exists():
        raise FileNotFoundError(f"Build completed but library not found at {library_path}")

    # Strip the shared library to reduce its size, if the strip tool is available
    try:
        strip_cmd = ["strip", str(library_path)]
        subprocess.run(strip_cmd, check=True)
        print(f"Stripped library: {library_path}")
    except Exception as e:
        print(f"Warning: Failed to strip library ({library_path}): {e}")

    lib_size = library_path.stat().st_size
    lib_size_mb = lib_size / (1024 * 1024)
    print(f"Library size: {lib_size_mb:.2f} MB")
    print(f"Library built successfully: {library_path}")
    return library_path

def copy_library(library_path, dest_dir=None):
    """Copy the library to the output directory"""
    library_name = __library_name()
    if dest_dir is None:
        dest_dir = current_dir
    else:
        dest_dir = Path(dest_dir)

    dest_path = dest_dir / f"{library_name}.so"

    print(f"Copying library: {library_path} -> {dest_path}")
    dest_dir.mkdir(parents=True, exist_ok=True)
    shutil.copy2(library_path, dest_path)
    print(f"  Library copied successfully")
    return dest_path

class BuildExtCommand(build_ext):
    """Custom build_ext command that builds the library and treats it as an extension"""
    def run(self):
        # Clone the repository first
        clone_repo(git_tag=os.environ.get('SEEKDB_GIT_TAG', 'master'))
        install_dependencies()

        # Build the library first
        if os.environ.get('SEEKDB_BUILD_LIBRARY', '1').upper() in ('1', 'ON', 'YES', 'TRUE'):
            library_path = build_library()

            # Copy library to build directory so it's treated as an extension module
            build_lib_dir = Path(self.build_lib) / __package_name()
            copy_library(library_path, build_lib_dir)

            # Also copy to source directory for package_data
            copy_library(library_path, current_dir)
        else:
            print("Skipping library build (SEEKDB_BUILD_LIBRARY is disabled)")

        # Run the standard build_ext (which will handle the extension modules)
        super().run()

ext_modules = [Extension(
    __library_name(),
    sources=[],  # No sources - we'll copy the pre-built library
    extra_objects=[],  # Will be handled by build_ext
)]

setup(
    name=__package_name(),
    version=get_version(),
    description=get_description(),
    long_description=get_long_description(),
    long_description_content_type="text/markdown",
    author="OceanBase",
    author_email="open_oceanbase@oceanbase.com",
    maintainer="OceanBase",
    maintainer_email="open_oceanbase@oceanbase.com",
    url="https://github.com/oceanbase/seekdb",
    project_urls={
        "Homepage": "https://github.com/oceanbase/seekdb",
        "Repository": "https://github.com/oceanbase/seekdb",
        "Documentation": "https://github.com/oceanbase/seekdb",
        "Bug Tracker": "https://github.com/oceanbase/seekdb/issues",
    },
    packages=[__package_name()],
    package_dir={f"{__package_name()}": "."},
    include_package_data=True,
    ext_modules=ext_modules,
    cmdclass={
        'build_ext': BuildExtCommand
    },
    keywords=["database", "oceanbase", "vector-database", "embed", "sql", "AI"],
    classifiers=[
        "Development Status :: 4 - Beta",
        "Intended Audience :: Developers",
        "Operating System :: POSIX :: Linux",
        "Programming Language :: Python :: 3",
        "Programming Language :: Python :: 3.8",
        "Programming Language :: Python :: 3.9",
        "Programming Language :: Python :: 3.10",
        "Programming Language :: Python :: 3.11",
        "Programming Language :: Python :: 3.12",
        "Programming Language :: Python :: 3.13",
        "Programming Language :: Python :: 3.14",
        "Programming Language :: C++",
        "Topic :: Database",
        "Topic :: Software Development :: Libraries :: Python Modules",
    ],
    python_requires=">=3.8",
    platforms=["manylinux"],
    license="Apache 2.0"
)

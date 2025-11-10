from setuptools import setup, find_packages

setup(
    name="interop_spike",
    version="0.1.0",
    packages=find_packages(),
    package_data={
        "interop_spike": ["bin/*"]
    },
    include_package_data=True,
    python_requires=">=3.7",
    classifiers=[
        "Programming Language :: Python :: 3.7",
        "Operating System :: OS Independent",
    ],
)
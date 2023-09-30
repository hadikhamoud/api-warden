from setuptools import setup, find_packages

setup(
    name='api-warden',
    version='0.1',
    packages=find_packages(),
    scripts=['bin/api-warden'], 
    entry_points={
        'console_scripts': [
            'api-warden = watcher.cli:main',
        ],
    },

)


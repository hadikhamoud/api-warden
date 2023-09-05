from setuptools import setup, find_packages

setup(
    name='api-warden',
    version='0.1',
    packages=find_packages(),
    install_requires=[        
    ],
    entry_points={
        'console_scripts': [
            'apiwarden= main:main',
        ],
    },
)
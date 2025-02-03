# Reolution measurements from beads

Collection of ipython notebooks for measuring resolution from images with 300nm beads.

## Setup

1) Clone the repository
2) Navigate to `MBEN/BeadResolution`
3) Create a python virtual environment and install the required packages  
```
python3 -m venv bead_resolution
source bead_resolution/bin/activate
pip3 install -r requirements.txt
```
4) Connect the environment to the JupyterHub/JupyterNotebook
5) Run the notebooks

## Contents
Notebooks for the following technologies are available:
- Molecular Cartography
- Xenium
- RNAscope (Dragonfly confocal microscope)
- Merscope
  
## General workflow
Which the processing of each image type is different the notebooks follow a common workflow:
1) Cleanup/Threshold the image.
2) Find local maxima (https://scikit-image.org/docs/stable/auto_examples/segmentation/plot_peak_local_max.html).
3) Measure the signal to noise ratio (https://scikit-image.org/docs/stable/auto_examples/segmentation/plot_peak_local_max.html).
4) Calculate the FWHM for every peak along the Z,Y,X axes (https://docs.scipy.org/doc/scipy/reference/generated/scipy.signal.peak_widths.html).
5) Plots the identified local maima over the image.

public: yes

Optic Disc Segmentation
=======================

The cup-to-disc ratio is an important statistic in diagnosing glaucoma.
However segmentation must be done manually which is quite tedious and
time-consuming. Also, there is large variability between specialists. This
research is an attempt to apply graph search techniques to the segmentation
problem in an attempt to improve upon current pixel classification techniques.

Techniques
----------

- Pixel Classification
- Probability Map Computation
- Feature Selection
- Cost Function Optimization
- Convex Shape Segmentation
- Simultaneous Cup/Disc Segmentation
- Combining Region-based and Edge-based Information

Pixel Classification and Probability Maps
-----------------------------------------

We utilize k-NN nearest neighbor classification on feature vectors to compute
probability maps representing membership in each region within the image.
Pixel classification has the advantage that it can incorporate large amounts
of information about a particular pixel into a classification.

Examples of different probability maps are shown below.

.. image:: /research/images/od-1t.png
    :alt: probability map ex. 1

.. image:: /research/images/od-2t.png
    :alt: probability map ex. 2

.. image:: /research/images/od-3t.png
    :alt: probability map ex. 3

Feature Selection
-----------------

Feature selection techniques are used to reduce the feature set from 250+
features down to only the 6 most signification features used for detecting
the optic disc. We use an automated tool to generate many different low-level
features on a single image such as Gaussians at different scales, edge
detectors, etc. The features are computed on the HSV, RGB and Color
Opponency (RG, BY, Brightness) planes.

.. image:: /research/images/od-4t.png
    :alt: all computed features

.. image:: /research/images/od-5t.png
    :alt: selected features

Cost Function Optimization
--------------------------

Optimization of the cost function involves the selection of the most
significant features from a set. Relevant features are determined by feature
selection which optimizes the cost functions based on the difference between
the computer segmentation and the reference standard. Our optimization
pipeline is unique because the error metric used in feature computation
involves the final output of the graph search, not simply the differences in
classifications.

Images below show, from left to right, the original image, the computer
segmentation using our algorithm and the reference standard.

.. image:: /research/images/od-6t.png
    :alt: segmented nerve ex. 1

.. image:: /research/images/od-7t.png
    :alt: segmented nerve ex. 2

Publications
------------

Journal Articles
~~~~~~~~~~~~~~~~

.. [JGAA2007] "Simultaneous Border Segmentation of Doughnut-Shaped Objects in
    Medical Images", with X Wu, **MB Merickel**, *Journal of Graph Algorithms and
    Applications*, Vol. 11(1), 2007.
    `[PDF] </research/files/WuMerickel2007.11.1.pdf>`__
    `[JGAA] <http://jgaa.info/volume11.html>`__

Conference Proceedings
~~~~~~~~~~~~~~~~~~~~~~

.. [SPIE2007] "Segmentation of the Optic Nerve Head Combining Pixel
    Classification and Graph Search", with **MB Merickel JR**, MD Abramoff,
    M Sonka, X Wu, *Proc. of SPIE Image Processing*, Vol. 6512, 2007.
    `[PDF] </research/files/spie07-optic_nerve.pdf>`__
    `[NOTICE] </research/files/spie07-copyright.txt>`__
    `[SPIE] <http://dx.doi.org/10.1117/12.710588>`__

.. [SPIE2006] "Optimal Segmentation of the Optic Nerve Head from Stereo
    Retinal Images", with **MB Merickel JR**, X Wu, M Sonka, MD Abramoff,
    *Proc. of SPIE Physiology and Function*, Vol. 6143, 2006.
    `[PDF] </research/files/spie06-optic_nerve.pdf>`__
    `[NOTICE] </research/files/spie06-copyright.txt>`__
    `[SPIE] <http://dx.doi.org/10.1117/12.657923>`__


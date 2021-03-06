require(retistruct)
require(rgl)
require(fields)
require(RColorBrewer)
require(sphereplot)
require(mapproj)

options(rgl.useNULL = FALSE)

##' @title Retinal Object Construction
##' @description This is the primary way to create a retinal object, which contains all of the information required to reconstruct, map, visualize, and interpret retinal cell density data.
##' @param path string of the retinal data directory. Should contain an xyz.csv file, falc.txt, and the saved retistruct() markup data
##' @param LD lens diameter mm
##' @param ED eye diameter mm
##' @param AL axial length mm
##' @param height counting frame height in micrometers
##' @param width counting frame width in micrometers
##' @param lambda Lambda value passed to the thin plate spline interpolator.
##' @param extrapolate logical, default is TRUE so values are extrapolated to the equator.
##' @param rotation_ccw Dorsal is up by default at -90 degrees.
##' @param IJcoords set of imageJ coordinates, in the format of data.frame(maxX=_, maxY=_, minX=_, minY=_, deltaX=_, deltaY=_). Replace _ with recorded values within ImageJ.
##' @param spatial_res resolution, default is 16 for speed.
##' @param ... further arguments passed to or from other methods.
##' @return ret_obj retinal object (list)
##' @author Brian Cohn \email{brian.cohn@@usc.edu}
##' @export
retina_object <- function(path, LD, ED, AL, height, width, lambda = 0.01, extrapolate = TRUE, 
    spatial_res = 16, rotation_ccw = -90, IJcoords = FALSE, ...) {
    
    if (height != width) {
        stop("Height is not equal to Width. \n
\t\t\t  Must be square counting frame. \n
\t\t\t  Email brian.cohn@usc.edu if you want to request this feature.")
    }
    
    xyz_df <- import_xyz(path)
    rownames(xyz_df) <- NULL
    save_flatmount_coordinates_to_datapoints(path, xyz_df, IJcoords = IJcoords, falciform = TRUE)
    sph_coords <- spherical_coords(path, xyz_df, height, width, falciform = TRUE)
    trimmed_data <- sph_coords[[1]]
    falc_coords <- sph_coords[[2]]
    # Produce an OpenGL visualization of the counting frame locations, as they are
    # reconstructed upon a hemisphere sphere_visualize(trimmed_data)
    
    # Create an azimuthal equidistant map projection for the density locations
    az <- mapproject(x = trimmed_data[, 2], trimmed_data[, 1], projection = "azequidistant", 
        orientation = c(-90, 0, rotation_ccw))
    # Append the data measurements to the density locations
    az$z <- trimmed_data[, 3]
    
    falc_az <- mapproject(x = falc_coords[, 2], falc_coords[, 1], projection = "azequidistant", 
        orientation = c(-90, 0, rotation_ccw))
    # our transformed lambda value az$x our transformed phi value az$y plot(az) #plot
    # to see how the azimuthal equidistant plotter distributes the points over a
    # cartesian frame.  plot3d(az$x,az$y,az$z) #plot with density to show the
    # distribution in 3 dimensions (to verify proper orientation and density
    # magnitude)
    
    
    # fit_plot_azimuthal fits the azimuthal data to a thin plate spline interpolator
    # The funciton then uses this model fit to predict what density would be across
    # the hemispherical surface. The smooth predicted surface is colored by it's
    # density; Purple:White:Orange for low to high density.
    fit_data <- fit_plot_azimuthal(az$x, az$y, z = az$z, outer_radius = 1.6, spatial_res = spatial_res, 
        lambda = lambda, col_levels = 50, contour_levels = 20, extrapolate = extrapolate, 
        compute_error = TRUE, eye_diameter = ED, axial_len = AL, falciform_coords = falc_az, 
        ...)  #plot the image, function derived from http://stackoverflow.com/questions/10856882/r-interpolated-polar-contour-plot
    
    retina_object <- c(fit_data = fit_data, LD = LD, ED = ED, AL = AL, trimmed_data = list(trimmed_data), 
        azimuthal_data = list(falciform = list(falc_az), datapoints = list(az)))  #combine the retina (micro) and ocular (macro) data.
    message("View the walkthrough tutorial here: https://github.com/briancohn/retina/blob/master/tutorial.md")
    return(retina_object)
}

IJ_xyz_df_to_xyz_df <- function(xyz_df, IJcoords, inversion){
	sbrowser()
	# xyz_df$x <- IJcoords$minX + (xyz_df$x - 1) * IJcoords$deltaX
	x <- xyz_df$x
	y <- xyz_df$y
	x <- (x-min(x))/(max(x)-min(x))
	y <- (y-min(y))/(max(y)-min(y))
	normalized_xy_df <- data.frame(x=x, y=y)
	return(0)
}

save_flatmount_coordinates_to_datapoints <- function(path, xyz_df, IJcoords, falciform = TRUE) {
    
    # Read in the Falciform Process x y outline coordinates.
    if (falciform == TRUE) {
        falc <- read.table(paste0(path, "/falc.txt"), col.names = c("x", "cyan"))
    } else {
        # If not, just put in NULL.
        falc <- data.frame()
    }
    # Import Counting Frame surface area in microns^2
    
    if (IJcoords == FALSE) {
        # TODO add confirmation that all points in xyz_df lie within the outline.
        normalized_coordinates <- xyz_df
    } else {
        normalized_coordinates <- coordinate_IJ(xyz_df, IJcoords$maxX, IJcoords$maxY, 
            IJcoords$minX, IJcoords$minY, IJcoords$deltaX, IJcoords$deltaY, inversion = FALSE)
    }
    # Save output/species/datapoints.csv, create folder if doesnt exist #saves only
    # the x,y coordinates
    DAT <- data.frame(normalized_coordinates[, 1], normalized_coordinates[, 2])
    xyz_len <- nrow(normalized_coordinates)
    # Append the falciform process to the end of the dataset.
    colnames(DAT) <- c("x", "cyan")
    DAT <- rbind(DAT, falc)  #Tag the falciform process onto the end
    combined_len <- length(DAT[, 1])
    # Save the points as datapoints.csv. This includes XYZ datapoints and the
    # falciform process.
    write.csv(DAT, file = paste0(path, "/datapoints.csv"), row.names = FALSE)
    return(0)
}

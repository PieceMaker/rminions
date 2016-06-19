stealTheMoonSim <- function(params) {
    surfaceFuelDependenceCop <- copula::claytonCopula(params$surfaceFuelDependenceCopParams$param, dim = 2)

    baseFuel <- rlnorm(1, meanlog = params$fuelParams$meanlog, sdlog = params$fuelParams$sdlog)

    # Solar flares occurring during trip
    numSolarFlares <- rpois(1, lambda = params$solarFlareParams$lambda)
    flareSurface <- rgamma(numSolarFlares, shape = params$flareSurfaceParams$shape, scale = params$flareSurfaceParams$scale)
    flareSurfaceUnif <- pgamma(flareSurface, shape = params$flareSurfaceParams$shape, scale = params$flareSurfaceParams$scale)
    flareAdditionalFuelUnif <- copula::rtrafo(
        u = as.matrix(
            cbind(
                flareSurfaceUnif,
                runif(numSolarFlares)
            )
        ),
        cop = surfaceFuelDependenceCop,
        j.ind = 2,
        inverse = T
    )
    # Additional required fuel due to solar flares, converted to millions of pounds
    flareAdditionalFuel <- qlnorm(flareAdditionalFuelUnif, meanlog = params$flareAdditionalFuelParams$meanlog, sdlog = params$flareAdditionalFuelParams$sdlog)/10

    # Asteroids along path
    asteroidsOnPath <- rpois(10000000, lambda = params$asteroidParams$lambda)
    asteroidSegments <- which(asteroidsOnPath > 0)
    numAsteroids <- sum(asteroidsOnPath)
    # Additional required fuel due to dodging asteroids, converted to millions of pounds
    asteroidAdditionalFuel <- rnorm(numAsteroids, mean = params$asteroidAdditionalFuelParams$mean, sd = params$asteroidAdditionalFuelParams$sd) / 10000

    totalFuel <- baseFuel + sum(flareAdditionalFuel) + sum(asteroidAdditionalFuel)

    response <- list(
        numSolarFlares = numSolarFlares,
        flareSurface = flareSurface,
        baseFuel = baseFuel,
        flareAdditionalFuel = flareAdditionalFuel,
        asteroidSegments = asteroidSegments,
        asteroidsPerSegment = asteroidsOnPath[asteroidSegments],
        asteroidAdditionalFuel = asteroidAdditionalFuel,
        totalFuel = totalFuel
    )
    return(response)
}
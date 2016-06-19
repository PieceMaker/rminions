stealTheMoonSim <- function(params) {
    # Assume base fuel required (in millions of pounds) is lognormally distributed with meanlog 0.25 and sdlog 0.25
    fuelParams <- list(
        meanlog = 0.25,
        sdlog = 0.25
    )

    # Assume traveling to moon at peak solar flare season and that the number of flares for the trip can be
    # modeled as Poisson with mean 4.
    solarFlareParams <- list(
        lambda = 4
    )

    # Assume flare emitting surface (as a multiple of 100) for each flare is gamma distributed with shape 6 and
    # scale 0.75
    flareSurfaceParams <- list(
        shape = 6,
        scale = 0.75
    )

    # Assume additional amount of fuel required due to flares (in 100,000 pounds) is lognormally distributed with
    # meanlog 0.2 and sdlog 0.5
    flareAdditionalFuelParams <- list(
        meanlog = 0.2,
        sdlog = 0.5
    )

    # Assume dependence structure between flare emitting surface and additional Fuel required can be modeled
    # with a Clayton copula with parameter 10
    surfaceFuelDependenceCop <- copula::claytonCopula(10, dim = 2)

    # TODO: Try to add asteroid model
    # An asteroid shower is expected to occur while travelling too and from the Moon. Assume the travel path
    # to moon has been divided into 10,000,000 segments and that the number of asteroids we have to dodge in any
    # segment is distributed Poisson with lambda 0.000005.
    asteroidParams <- list(
        lambda = 0.000005
    )

    # Assume the additional amount of fuel required (in 100 pounds) for dodging an asteroid is normally
    # distributed with mean 1.5 and sd 0.25.
    asteroidAdditionalFuelParams <- list(
        mean = 1.5,
        sd = 0.25
    )

    baseFuel <- rlnorm(1, meanlog = fuelParams$meanlog, sdlog = fuelParams$sdlog)
    numSolarFlares <- rpois(1, lambda = solarFlareParams$lambda)
    flareSurface <- rgamma(numSolarFlares, shape = flareSurfaceParams$shape, scale = flareSurfaceParams$scale)
    flareSurfaceUnif <- pgamma(flareSurface, shape = flareSurfaceParams$shape, scale = flareSurfaceParams$scale)
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
    flareAdditionalFuel <- qlnorm(flareAdditionalFuelUnif, meanlog = flareAdditionalFuelParams$meanlog, sdlog = flareAdditionalFuelParams$sdlog)/10

    # Asteroids along path
    asteroidsOnPath <- rpois(10000000, lambda = asteroidParams$lambda)
    asteroidSegments <- which(asteroidsOnPath > 0)
    numAsteroids <- sum(asteroidsOnPath)
    # Additional required fuel due to dodging asteroids, converted to millions of pounds
    asteroidAdditionalFuel <- rnorm(numAsteroids, mean = asteroidAdditionalFuelParams$mean, sd = asteroidAdditionalFuelParams$sd) / 10000

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
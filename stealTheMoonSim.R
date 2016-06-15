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

    # Assume additional amount of fuel required (in 100,000 pounds) is lognormally distributed with meanlog 0.2
    # and sdlog 0.5
    additionalFuelParams <- list(
        meanlog = 0.2,
        sdlog = 0.5
    )

    # Assume dependence structure between flare emitting surface and additional Fuel required can be modeled
    # with a Clayton copula with parameter 10
    surfaceFuelDependenceCop <- copula::claytonCopula(10, dim = 2)

    # TODO: Try to add asteroid model

    baseFuel <- rlnorm(1, meanlog = fuelParams$meanlog, sdlog = fuelParams$sdlog)
    numSolarFlares <- rpois(1, lambda = solarFlareParams$lambda)
    flareSurface <- rgamma(numSolarFlares, shape = flareSurfaceParams$shape, scale = flareSurfaceParams$scale)
    flareSurfaceUnif <- pgamma(flareSurface, shape = flareSurfaceParams$shape, scale = flareSurfaceParams$scale)
    additionalFuelUnif <- rtrafo(
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
    # Additional required fuel, converted to millions of pounds
    additionalFuel <- qlnorm(additionalFuelUnif, meanlog = additionalFuelParams$meanlog, sdlog = additionalFuelParams$sdlog)/10
    totalFuel <- baseFuel + sum(additionalFuel)

    response <- list(
        numSolarFlares = numSolarFlares,
        flareSurface = flareSurface,
        additionalFuel = additionalFuel,
        totalFuel = totalFuel
    )
    return(response)
}
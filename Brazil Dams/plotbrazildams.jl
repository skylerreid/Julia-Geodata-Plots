using CSV, DataFrames, Plots, ColorSchemes, Shapefile, Statistics
filename = "filepath to your csv"

data = CSV.read(filename, DataFrame; delim = ',')
latitudes = data[1:end, 4]
longitudes = data[1:end, 5]
sizes = data[1:end, 8]

mask1 = .!ismissing.(sizes)  # boolean array that is true for non-missing values

latitudes = latitudes[mask1]
longitudes = longitudes[mask1]
sizes = sizes[mask1]

shp = Shapefile.Table("filepath to your shp")
df = DataFrame(shp)

p1 = plot(aspect_ratio=:equal)  # set equal to avoid weird scaling issue
geom = df.geometry[30] # Brazil is at index 30

# Function to check if a point is inside a polygon. call this in a loop later
function is_inside(point, polygon_points)
    n = length(polygon_points)
    inside = false
    p1x, p1y = polygon_points[n].x, polygon_points[n].y
    for i in 1:n
        p2x, p2y = polygon_points[i].x, polygon_points[i].y
        if ((p2y > point[2]) != (p1y > point[2])) &&
           (point[1] < (p1x - p2x) * (point[2] - p2y) / (p1y - p2y) + p2x)
            inside = !inside
        end
        p1x, p1y = p2x, p2y
    end
    return inside
end

# Filter points within Brazil's geometry
brazil_latitudes = Float64[]
brazil_longitudes = Float64[]
brazil_sizes = Float64[]

parts = geom.parts .+ 1  # convert to 1-based indexing (geom starts at zero)
points = geom.points
part_ends = vcat(parts[2:end], length(points) + 1)

for i in 1:length(latitudes)
    point = (longitudes[i], latitudes[i]) # check longs first, then lats
    is_in_country = false
    for (start_idx, end_idx) in zip(parts, part_ends)
        ring = points[start_idx:end_idx-1]
        if is_inside(point, ring)           #call is_inside function
            is_in_country = true
            break # If inside any part (assuming outer boundary first), it's inside
        end
    end
    if is_in_country
        push!(brazil_latitudes, latitudes[i])
        push!(brazil_longitudes, longitudes[i])
        push!(brazil_sizes, sizes[i])
    end
end

# Filter points by size outliers
mean_size = mean(brazil_sizes)
std_size = std(brazil_sizes)
threshold = 4 * std_size

filtered_latitudes = Float64[]
filtered_longitudes = Float64[]
filtered_sizes = Float64[]

for i in 1:length(brazil_sizes)
    if abs(brazil_sizes[i] - mean_size) <= threshold
        push!(filtered_latitudes, brazil_latitudes[i])
        push!(filtered_longitudes, brazil_longitudes[i])
        push!(filtered_sizes, brazil_sizes[i])
    end
end

p1 = plot(aspect_ratio=:equal)
for (start_idx, end_idx) in zip(parts, part_ends)
    ring = points[start_idx:end_idx-1]
    xs = [pt.x for pt in ring]
    ys = [pt.y for pt in ring]
    plot!(p1, xs, ys, color=:lightgray, lw=2, label=false)
end

scatter!(p1, filtered_longitudes, filtered_latitudes, marker_z=filtered_sizes,
         markersize=2, colorbar=true,
         palette=:roma, label="Reservoir Capacity",
         title="Locations and Sizes of Dams in Brazil")

display(p1)

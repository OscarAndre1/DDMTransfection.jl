module DDMTransfection

using Images
using SparseArrays
using SegmentationUtils

using StatsBase
using RegionProps
using DataFrames



function get_lims(x,spacing::Int64)
    x = floor(Int, x)
    x-spacing:x+spacing
end
otsu_segment(img) = img .> otsu_threshold(img)


function measure_in_window(window, window_ref,label_id; minsize=50)
    labels = label_components(otsu_segment(window))
    overlap = let
        _keys = Set(labels[window_ref])
        pop!(_keys, 0)
        _keys .∈ labels
    end
    
    if !any(overlap) || sum(overlap) < minsize
        overlap = window_ref
    end
    
    intensity_arr = window[overlap]
    (major_axis, minor_axis), _ = RegionProps.ellipse_properties(Int64.(overlap),1)
    
    props = map(f -> f(intensity_arr), (;median,mean,std,sum,length))
    merge(props, (;major_axis,minor_axis,label_id))
end


function measure_object_intensities(labeled_image,
        image,
        config;
        reference_channel=1,
        spacing=30,
        kwargs...
    )
    objects = regionprops(
        image[reference_channel, :,:],
        labeled_image;
        selected = unique(nonzeros(labeled_image))
        )
    
    pos = let o = objects
        zip(o.centroid_x, o.centroid_y, o.label_id)
    end
    
    ref_windows = map(pos) do (x,y,l)
        ylims = get_lims(y, spacing)
        xlims = get_lims(x, spacing)
        l => image[reference_channel, ylims,xlims] .== l
    end |> Dict
    
    props = map(config) do c
        name = c["name"]
        i = c["index"]
        props = map(pos) do (x,y,seed_lb)
            ylims,xlims = get_lims.((y,x), spacing)
            
            window = image[i, ylims,xlims]
            measure_in_window(window, ref_windows[seed_lb], seed_lb)
        end |> DataFrame
        for col in filter(x->x !== "label_id", names(props))
            rename!(props, col => join([col, name], "_"))
        end
        props
    end
    innerjoin(props..., on=:label_id)
    props
end

function filter_objects_in_image(labeled_image, minsize, maxsize)
    sparse_lb = sparse(labeled_image)
    counts = countmap(nonzeros(sparse_lb))
    for (i,j,v) in zip(findnz(sparse_lb)...)
        if counts[v] < minsize || counts[v] > maxsize
            lb[i,j] = 0
        end
    end
    dropzeros!(labeled_image)
end

function segment_reference_image(image;
        n_sigma=3,
        reference_channel=1,
        minsize=500,
        maxsize=2000,
        kwargs...
    )
    i = reference_channel
    ref_img = image[i,:,:]
    
    m,s = sigma_clipped_stats(ref_img)
    
    labeled_image = @chain ref_img begin
        _ .> m + (s * n_sigma)
        label_components
        filter_objects_in_image(_,minsize,maxsize)
    end
    
    return labeled_image
end

function drop_empty_dims(image)
    dims = Tuple(findall(x -> x.val.stop == 1, img.data.axes))
    dropdims(img.data.data;dims)
end

MultiPointAnalysis("Transfection") do image, config
    
    image = drop_empty_dims(image)
    seg_params = config["segmentation"]
    labeled_image = segment_reference_image(image, to_named_tuple(seg_params)...)
    
    return measure_overlapping_intensities(
        labeled_image,
        image,
        config["channels"];
        to_named_tuple(seg_params)...
    )
    
end

MultiPointAnalysis("BackgroundStats") do image, config
    
    image = drop_empty_dims(image)
    
    channel_definitions = config["channels"]
    
    return map(channel_definitions) do def
        i = def["index"]
        name = def["name"]
        m,s = sigma_clipped_stats(img[i, :,:])
        max_intensity = maximum(img[i,:,:])
        (definition = Symbol(name), median = m, std = s, max_intensity)
    end |> DataFrame

    
end
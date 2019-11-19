pro get_match_up_values
  
  compile_opt idl2
  e = envi()
  
  fn_csv = "St_20170724.csv"
  fn_img = "Rrs_dw_20170724T015012_water_bb.dat"
  print, match_up_old(fn_csv, fn_img, e)

end


function match_up, fn_csv, fn_img, e

  data = read_csv(fn_csv, count=nsta)
  Sta_name = data.(0)
  Lon = data.(1)
  Lat = data.(2)
  
  raster = e.OpenRaster(fn_img)
  wavelength = round(raster.Metadata['WAVELENGTH'])
  
  spatialref1 = raster.spatialref
  spatialref1.ConvertLonLatToMap, Lon, Lat, MapX, MapY
  
  Task = ENVITask('ConvertGeographicToMapCoordinates')
  Task.Input_Coordinate=transpose([[lon],[lat]])
  Task.SPATIAL_REFERENCE = raster.spatialref
  Task.Execute
  
  roi = ENVIROI(NAME='Match Points', COLOR='Green')
  data = Task.OUTPUT_COORDINATE
  roi.AddGeometry, data, coord_sys=raster.SpatialRef.Coord_Sys_Str, /POINT
  
  view = e.GetView()
  layer = view.CreateLayer(raster)
  roiLayer = layer.AddROI(roi)
  
  match_pixel = roi.PixelAddresses(raster)
  num = (size(match_pixel))[2]
  data = fltarr(n_elements(wavelength), num)
  for i = 0, num-1 do begin
    sub_rect = [match_pixel[0,i],match_pixel[1,i],match_pixel[0,i],match_pixel[1,i]]
    rrs = reform(raster.getData(bands=indgen(raster.nbands), sub_rect=sub_rect))
    data[*,i] = rrs
  endfor
  
  header = ['Stations',strcompress(string(wavelength),/remove_all)]
  body = [transpose(Sta_name),strcompress(string(data),/remove_all)]
  o_fn = file_dirname(fn_img) + '\' + file_basename(fn_img, '.dat') + '.csv'
  
  write_csv, o_fn, body, header=header
  return, o_fn
  
  roi.Close
  
end

function match_up_old, fn_csv, fn_img, e
  
  data = read_csv(fn_csv, count=nsta)
  Sta_name = data.(0)
  Lon = data.(1)
  Lat = data.(2)

  raster = e.OpenRaster(fn_img)
  wavelength = round(raster.Metadata['WAVELENGTH'])
  fid = ENVIRastertoFid(raster)
  map_info = envi_get_map_info(fid=fid)
  envi_file_query, fid, dims=dims, nl=nl, ns=ns, nb=nb, wl=wl, bnames=bnames
  i_proj = envi_proj_create(/geographic, datum = 'WGS-84')
  o_proj = map_info.proj
  envi_convert_projection_coordinates, lon, lat, i_proj, xmap, ymap, o_proj
  envi_convert_file_coordinates, fid, xf, yf, xmap, ymap
  xf = floor(xf) & yf=floor(yf)
  w = where(xf gt 0 and yf gt 0 and xf lt dims[2] and yf lt dims[4],count)
  nsta = count
  xf = xf[w] & yf = yf[w]
  data = fltarr(n_elements(wavelength),nsta)
  for i=0,nsta-1 do begin
    dims = [-1,xf[i],xf[i],yf[i],yf[i]]
    for ib = 0,nb-1 do data[ib,i] = envi_get_data(fid=fid,dims=dims,pos=ib)
  endfor
  
  header = ['Stations',strcompress(string(wavelength),/remove_all)]
  body = [transpose(Sta_name[w]),strcompress(string(data),/remove_all)]
  o_fn = file_dirname(fn_img) + '\' + file_basename(fn_img, '.dat') + '.csv'

  write_csv, o_fn, body, header=header
  return, o_fn
  
end



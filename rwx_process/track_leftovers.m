            %run tracking algorithm if sig_refl has been detected
            if grid_obj.sig_refl==1 && ~isempty(proc_obj)
                %tracking
                %updated_storm_jstruct = process_wdss_tracking(grid_obj.start_dt,grid_obj.radar_id);
                %generate nowcast json on s3 for realtime data
                if realtime_flag == 1
                     storm_nowcast_json_wrap(dest_root,updated_storm_jstruct,grid_obj);
                     %storm_nowcast_svg_wrap(dest_root,updated_storm_jstruct,grid_obj);
                end
            else
                %remove nowcast files is no prc_objects exist anymore
                nowcast_root = [dest_root,num2str(radar_id,'%02.0f'),'/nowcast.'];
                file_rm([nowcast_root,'json'],0,1)
                %file_rm([nowcast_root,'wtk'],0)
                %file_rm([nowcast_root,'svg'],0)
            end
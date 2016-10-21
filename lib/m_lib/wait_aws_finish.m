function wait_aws_finish

%wait for aws processes to finish
while true
    [~,eout] = unix('pgrep aws | wc -l');
    if str2num(eout)>0
        pause(0.2);
        display(['aws processing running ',eout]);
    else
        break
    end
end